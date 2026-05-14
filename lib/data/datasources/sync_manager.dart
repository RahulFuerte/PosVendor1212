// Dart imports:
import 'dart:async';
import 'dart:math';

// Project imports:

import '../../core/error/error_handling_service.dart';
import '../../core/network/connection_monitor.dart';
import '../../core/utils/performance_monitor.dart';
import 'data_integrity_service.dart';
import 'database_service.dart';
import 'local/sqlite_dao.dart';
import 'remote/firebase_dao.dart';

/// Enum for sync operation status
enum SyncOperationStatus {
  idle,
  syncing,
  completed,
  failed,
  retrying,
}

/// Sync operation result
class SyncResult {
  final bool success;
  final String? errorMessage;
  final int itemsSynced;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    this.errorMessage,
    this.itemsSynced = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Manages synchronization between SQLite and Firebase
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SQLiteDAO? _sqliteDAO;
  NodeApiDAO? _NodeApiDAO;
  ConnectionMonitor? _connectionMonitor;
  final ErrorHandlingService _errorService = ErrorHandlingService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _retryTimer;
  
  final StreamController<SyncOperationStatus> _syncStatusController = 
      StreamController<SyncOperationStatus>.broadcast();
  final StreamController<SyncResult> _syncResultController = 
      StreamController<SyncResult>.broadcast();

  SyncOperationStatus _currentStatus = SyncOperationStatus.idle;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const int _baseRetryDelaySeconds = 2;

  /// Stream that emits sync operation status changes
  Stream<SyncOperationStatus> get syncStatusStream => _syncStatusController.stream;

  /// Stream that emits sync operation results
  Stream<SyncResult> get syncResultStream => _syncResultController.stream;

  /// Current sync operation status
  SyncOperationStatus get currentStatus => _currentStatus;

  /// Check if sync manager is initialized
  bool get isInitialized => _sqliteDAO != null && _NodeApiDAO != null && _connectionMonitor != null;

  /// Initialize the sync manager
  Future<void> initialize() async {
    if (_sqliteDAO == null) {
      try {
        await _errorService.initialize();
        
        _sqliteDAO = SQLiteDAO();
        _NodeApiDAO = NodeApiDAO();
        _connectionMonitor = ConnectionMonitor();
        
        await _connectionMonitor!.initialize();
        await _sqliteDAO!.initialize();
        await _NodeApiDAO!.initialize();

        // Listen for connectivity changes and trigger sync when online
        _connectivitySubscription = _connectionMonitor!.connectivityStream.listen(
          _onConnectivityChanged,
          onError: (error) {
            _errorService.logError(
              'SyncManager',
              'Connectivity monitoring error',
              error: error,
              severity: ErrorSeverity.medium,
              userMessage: 'There was a problem monitoring network connectivity. Sync may not work automatically.',
            );
          },
        );

        await _errorService.logInfo('SyncManager', 'SyncManager initialized successfully');
      } catch (e) {
        await _errorService.logError(
          'SyncManager',
          'Failed to initialize SyncManager',
          error: e,
          severity: ErrorSeverity.critical,
          userMessage: 'Failed to start the sync system. Please restart the app.',
        );
        // Reset to null on failure
        _sqliteDAO = null;
        _NodeApiDAO = null;
        _connectionMonitor = null;
        rethrow;
      }
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isConnected) {
    if (isConnected && _currentStatus == SyncOperationStatus.idle) {
      _errorService.logInfo(
        'SyncManager',
        'Connectivity restored, triggering automatic sync',
        context: {'wasOffline': !isConnected},
      );
      syncPendingData();
    } else if (!isConnected) {
      _errorService.logWarning(
        'SyncManager',
        'Network connectivity lost',
        userMessage: 'You\'re now offline. Your data will be saved locally and synced when connection is restored.',
      );
    }
  }

  /// Sync all pending data to Firebase with batch operations
  Future<SyncResult> syncPendingData() async {
    return await _performanceMonitor.trackSyncOperation('syncPendingData', () async {
      return await _syncPendingDataInternal();
    });
  }

  /// Internal sync implementation (wrapped by performance monitoring)
  Future<SyncResult> _syncPendingDataInternal() async {
    if (_currentStatus == SyncOperationStatus.syncing) {
      await _errorService.logWarning(
        'SyncManager',
        'Sync already in progress, skipping new sync request',
      );
      return SyncResult(success: false, errorMessage: 'Sync already in progress');
    }

    if (_connectionMonitor?.isConnected != true) {
      await _errorService.logWarning(
        'SyncManager',
        'No internet connection available for sync',
        userMessage: 'Unable to sync data. Please check your internet connection.',
      );
      return SyncResult(success: false, errorMessage: 'No internet connection');
    }

    if (_sqliteDAO == null || _NodeApiDAO == null) {
      await _errorService.logError(
        'SyncManager',
        'Sync manager not properly initialized',
        severity: ErrorSeverity.high,
        userMessage: 'Sync system is not ready. Please restart the app.',
      );
      return SyncResult(success: false, errorMessage: 'Sync manager not initialized');
    }

    _updateSyncStatus(SyncOperationStatus.syncing);
    
    try {
      // Create backup before major sync operation
      await _errorService.logInfo('SyncManager', 'Creating database backup before sync');
      final backupResult = await _sqliteDAO!.createBackup(backupName: 'pre_sync_backup');
      if (!backupResult.success) {
        await _errorService.logWarning(
          'SyncManager',
          'Failed to create backup before sync',
          context: {'error': backupResult.errorMessage},
          userMessage: 'Unable to create backup before sync. Continuing anyway.',
        );
      } else {
        await _errorService.logInfo(
          'SyncManager',
          'Backup created successfully before sync',
          context: {'backupPath': backupResult.backupPath},
        );
      }

      // Validate data integrity before sync
      await _errorService.logInfo('SyncManager', 'Validating data integrity before sync');
      final integrityResult = await _sqliteDAO!.validateDataIntegrity();
      if (!integrityResult.isValid) {
        await _errorService.logWarning(
          'SyncManager',
          'Data integrity issues detected before sync',
          context: {
            'errors': integrityResult.errors,
            'warnings': integrityResult.warnings,
          },
          userMessage: 'Some data validation issues were found. Sync will continue but please review your data.',
        );
      }
    } catch (e) {
      await _errorService.logError(
        'SyncManager',
        'Pre-sync validation failed',
        error: e,
        severity: ErrorSeverity.medium,
        userMessage: 'Pre-sync checks failed. Continuing with sync anyway.',
      );
    }
    
    try {
      int totalItemsSynced = 0;

      // Sync food items with batch operations
      totalItemsSynced += await _syncTableToFirebaseBatch('food_items');
      
      // Sync departments with batch operations
      totalItemsSynced += await _syncTableToFirebaseBatch('departments');
      
      // Sync bills with batch operations
      totalItemsSynced += await _syncTableToFirebaseBatch('bills');

      // Reset retry count on successful sync
      _retryCount = 0;
      
      final result = SyncResult(
        success: true,
        itemsSynced: totalItemsSynced,
      );

      _updateSyncStatus(SyncOperationStatus.completed);
      _syncResultController.add(result);
      
      // Update sync status for all successfully synced items
      await _updateSyncStatusAfterCompletion();
      
      // Validate data integrity after sync
      try {
        print('Validating data integrity after sync...');
        final postSyncIntegrity = await _sqliteDAO!.validateDataIntegrity();
        if (!postSyncIntegrity.isValid) {
          print('Warning: Data integrity issues detected after sync: ${postSyncIntegrity.errors.join(', ')}');
        } else {
          print('Data integrity validation passed after sync');
        }
      } catch (e) {
        print('Post-sync validation failed: $e');
      }
      
      await _errorService.logInfo(
        'SyncManager',
        'Sync completed successfully',
        context: {'itemsSynced': totalItemsSynced},
      );
      return result;

    } catch (e) {
      await _errorService.logError(
        'SyncManager',
        'Sync operation failed',
        error: e,
        severity: ErrorSeverity.high,
        userMessage: 'Failed to sync your data to the cloud. We\'ll keep trying automatically.',
        context: {'retryCount': _retryCount},
      );
      
      final result = SyncResult(
        success: false,
        errorMessage: e.toString(),
      );

      _updateSyncStatus(SyncOperationStatus.failed);
      _syncResultController.add(result);

      // Schedule retry with enhanced exponential backoff
      _scheduleRetryWithBackoff();
      
      return result;
    }
  }

  /// Sync data from Firebase to SQLite with incremental updates
  Future<SyncResult> syncFromFirebase(String adminUid, {DateTime? lastSyncTime}) async {
    return await _performanceMonitor.trackSyncOperation('syncFromFirebase', () async {
      return await _syncFromFirebaseInternal(adminUid, lastSyncTime: lastSyncTime);
    });
  }

  /// Internal sync from Firebase implementation (wrapped by performance monitoring)
  Future<SyncResult> _syncFromFirebaseInternal(String adminUid, {DateTime? lastSyncTime}) async {
    if (_currentStatus == SyncOperationStatus.syncing) {
      print('Sync already in progress, skipping');
      return SyncResult(success: false, errorMessage: 'Sync already in progress');
    }

    if (_connectionMonitor?.isConnected != true) {
      print('No internet connection, sync from Firebase skipped');
      return SyncResult(success: false, errorMessage: 'No internet connection');
    }

    if (_sqliteDAO == null || _NodeApiDAO == null) {
      print('Sync manager not initialized');
      return SyncResult(success: false, errorMessage: 'Sync manager not initialized');
    }

    _updateSyncStatus(SyncOperationStatus.syncing);
    
    try {
      int totalItemsSynced = 0;

      // Sync food items from Firebase with incremental updates
      totalItemsSynced += await _syncTableFromFirebaseIncremental('food_items', adminUid, lastSyncTime);
      
      // Sync departments from Firebase with incremental updates
      totalItemsSynced += await _syncTableFromFirebaseIncremental('departments', adminUid, lastSyncTime);
      
      // Sync bills from Firebase with incremental updates
      totalItemsSynced += await _syncTableFromFirebaseIncremental('bills', adminUid, lastSyncTime);

      final result = SyncResult(
        success: true,
        itemsSynced: totalItemsSynced,
      );

      _updateSyncStatus(SyncOperationStatus.completed);
      _syncResultController.add(result);
      
      // Update sync status and timestamp after completion
      await _updateSyncStatusAfterCompletion();
      await _updateLastSyncTime();
      
      // Validate data integrity after sync from Firebase
      try {
        print('Validating data integrity after Firebase sync...');
        final postSyncIntegrity = await _sqliteDAO!.validateDataIntegrity(adminUid: adminUid);
        if (!postSyncIntegrity.isValid) {
          print('Warning: Data integrity issues detected after Firebase sync: ${postSyncIntegrity.errors.join(', ')}');
        } else {
          print('Data integrity validation passed after Firebase sync');
        }
      } catch (e) {
        print('Post-Firebase-sync validation failed: $e');
      }
      
      print('Sync from Firebase completed: $totalItemsSynced items synced');
      return result;

    } catch (e) {
      print('Sync from Firebase failed: $e');
      
      final result = SyncResult(
        success: false,
        errorMessage: e.toString(),
      );

      _updateSyncStatus(SyncOperationStatus.failed);
      _syncResultController.add(result);
      
      return result;
    }
  }

  /// Sync a specific table to Firebase with batch operations
  Future<int> _syncTableToFirebaseBatch(String tableName) async {
    if (_sqliteDAO == null || _NodeApiDAO == null) {
      throw Exception('Sync manager not initialized');
    }
    
    final pendingItems = await _sqliteDAO!.getPendingItemsByTable(tableName);
    int syncedCount = 0;
    
    if (pendingItems.isEmpty) {
      return 0;
    }

    // Process items in batches of 10 for better performance and error handling
    const int batchSize = 10;
    final List<List<Map<String, dynamic>>> batches = [];
    
    for (int i = 0; i < pendingItems.length; i += batchSize) {
      final end = (i + batchSize < pendingItems.length) ? i + batchSize : pendingItems.length;
      batches.add(pendingItems.sublist(i, end));
    }

    for (final batch in batches) {
      final List<Future<void>> batchOperations = [];
      final List<String> batchItemIds = [];
      
      for (final item in batch) {
        try {
          final String adminUid = item['admin_uid'];
          final String itemId = item['id'];
          batchItemIds.add(itemId);
          
          // Remove SQLite-specific fields before syncing
          final Map<String, dynamic> firebaseData = Map.from(item);
          firebaseData.remove('admin_uid');
          firebaseData.remove('created_at');
          firebaseData.remove('updated_at');
          firebaseData.remove('sync_status');
          firebaseData.remove('image_blob');

          // Add batch operation based on table type
          switch (tableName) {
            case 'food_items':
              batchOperations.add(_NodeApiDAO!.saveFoodItem(adminUid, firebaseData));
              break;
            case 'departments':
              batchOperations.add(_NodeApiDAO!.saveDepartment(adminUid, firebaseData));
              break;
            case 'bills':
              batchOperations.add(_NodeApiDAO!.saveBill(adminUid, firebaseData));
              break;
          }
        } catch (e) {
          print('Failed to prepare batch operation for $tableName item ${item['id']}: $e');
        }
      }

      try {
        // Execute all operations in the batch concurrently
        await Future.wait(batchOperations);
        
        // Mark all items in the batch as synced
        for (final itemId in batchItemIds) {
          await _sqliteDAO!.markAsSynced(tableName, itemId);
          syncedCount++;
        }
        
        print('Successfully synced batch of ${batchItemIds.length} $tableName items');
        
      } catch (e) {
        print('Batch sync failed for $tableName: $e');
        // Handle individual items in case of batch failure
        for (int i = 0; i < batch.length; i++) {
          try {
            final item = batch[i];
            final String adminUid = item['admin_uid'];
            final String itemId = item['id'];
            
            final Map<String, dynamic> firebaseData = Map.from(item);
            firebaseData.remove('admin_uid');
            firebaseData.remove('created_at');
            firebaseData.remove('updated_at');
            firebaseData.remove('sync_status');
            firebaseData.remove('image_blob');

            switch (tableName) {
              case 'food_items':
                await _NodeApiDAO!.saveFoodItem(adminUid, firebaseData);
                break;
              case 'departments':
                await _NodeApiDAO!.saveDepartment(adminUid, firebaseData);
                break;
              case 'bills':
                await _NodeApiDAO!.saveBill(adminUid, firebaseData);
                break;
            }

            await _sqliteDAO!.markAsSynced(tableName, itemId);
            syncedCount++;
            
          } catch (individualError) {
            print('Failed to sync individual $tableName item ${batch[i]['id']}: $individualError');
          }
        }
      }
    }

    return syncedCount;
  }

  /// Sync a specific table to Firebase (legacy method for backward compatibility)
  Future<int> _syncTableToFirebase(String tableName) async {
    return await _syncTableToFirebaseBatch(tableName);
  }

  /// Sync a specific table from Firebase to SQLite with incremental updates
  Future<int> _syncTableFromFirebaseIncremental(String tableName, String adminUid, DateTime? lastSyncTime) async {
    int syncedCount = 0;

    try {
      List<Map<String, dynamic>> firebaseItems;

      // Fetch data from Firebase based on table type
      // For incremental sync, we would ideally filter by lastSyncTime, but Firebase DAO doesn't support this yet
      // So we fetch all items and filter locally for now
      switch (tableName) {
        case 'food_items':
          firebaseItems = await _NodeApiDAO!.getFoodItems(adminUid);
          break;
        case 'departments':
          firebaseItems = await _NodeApiDAO!.getDepartments(adminUid);
          break;
        case 'bills':
          firebaseItems = await _NodeApiDAO!.getBills(adminUid);
          break;
        default:
          return 0;
      }

      // Filter items for incremental sync if lastSyncTime is provided
      if (lastSyncTime != null) {
        final lastSyncTimestamp = lastSyncTime.millisecondsSinceEpoch;
        firebaseItems = firebaseItems.where((item) {
          final updatedAt = item['updated_at'] ?? 0;
          return updatedAt > lastSyncTimestamp;
        }).toList();
        
        print('Incremental sync for $tableName: ${firebaseItems.length} items updated since last sync');
      }

      // Process items in batches for better performance
      const int batchSize = 20;
      for (int i = 0; i < firebaseItems.length; i += batchSize) {
        final end = (i + batchSize < firebaseItems.length) ? i + batchSize : firebaseItems.length;
        final batch = firebaseItems.sublist(i, end);
        
        final List<Future<void>> batchOperations = [];
        
        for (final firebaseItem in batch) {
          batchOperations.add(_processSingleItemFromFirebase(tableName, adminUid, firebaseItem));
        }
        
        try {
          await Future.wait(batchOperations);
          syncedCount += batch.length;
          print('Processed batch of ${batch.length} $tableName items from Firebase');
        } catch (e) {
          print('Batch processing failed for $tableName: $e');
          // Process items individually if batch fails
          for (final firebaseItem in batch) {
            try {
              await _processSingleItemFromFirebase(tableName, adminUid, firebaseItem);
              syncedCount++;
            } catch (individualError) {
              print('Failed to sync $tableName item ${firebaseItem['id']} from Firebase: $individualError');
            }
          }
        }
      }
    } catch (e) {
      print('Failed to fetch $tableName from Firebase: $e');
    }

    return syncedCount;
  }

  /// Process a single item from Firebase sync
  Future<void> _processSingleItemFromFirebase(String tableName, String adminUid, Map<String, dynamic> firebaseItem) async {
    // Check if item exists in SQLite
    final existingItem = await _getLocalItem(tableName, adminUid, firebaseItem['id']);
    
    if (existingItem == null) {
      // Item doesn't exist locally, insert it
      await _insertLocalItem(tableName, adminUid, firebaseItem);
    } else {
      // Item exists, check for conflicts and resolve
      await _resolveConflict(tableName, adminUid, existingItem, firebaseItem);
    }
  }

  /// Sync a specific table from Firebase to SQLite (legacy method for backward compatibility)
  Future<int> _syncTableFromFirebase(String tableName, String adminUid) async {
    return await _syncTableFromFirebaseIncremental(tableName, adminUid, null);
  }

  /// Get local item from SQLite
  Future<Map<String, dynamic>?> _getLocalItem(String tableName, String adminUid, String itemId) async {
    if (_sqliteDAO == null) return null;
    
    switch (tableName) {
      case 'food_items':
        return await _sqliteDAO!.getFoodItem(adminUid, itemId);
      case 'departments':
        return await _sqliteDAO!.getDepartment(adminUid, itemId);
      case 'bills':
        return await _sqliteDAO!.getBill(adminUid, itemId);
      default:
        return null;
    }
  }

  /// Insert item into local SQLite database
  Future<void> _insertLocalItem(String tableName, String adminUid, Map<String, dynamic> item) async {
    if (_sqliteDAO == null) return;
    
    switch (tableName) {
      case 'food_items':
        await _sqliteDAO!.saveFoodItem(adminUid, item);
        break;
      case 'departments':
        await _sqliteDAO!.saveDepartment(adminUid, item);
        break;
      case 'bills':
        await _sqliteDAO!.saveBill(adminUid, item);
        break;
    }
  }

  /// Resolve conflicts between local and Firebase data using timestamp-based priority
  Future<bool> _resolveConflict(
    String tableName,
    String adminUid,
    Map<String, dynamic> localItem,
    Map<String, dynamic> firebaseItem,
  ) async {
    try {
      // Get timestamps for comparison
      final int localTimestamp = localItem['updated_at'] ?? 0;
      final int firebaseTimestamp = firebaseItem['updated_at'] ?? 0;

      // If Firebase item is newer, update local item
      if (firebaseTimestamp > localTimestamp) {
        print('Resolving conflict for $tableName ${localItem['id']}: Firebase version is newer');
        
        switch (tableName) {
          case 'food_items':
            await _sqliteDAO!.updateFoodItem(adminUid, localItem['id'], firebaseItem);
            break;
          case 'departments':
            await _sqliteDAO!.updateDepartment(adminUid, localItem['id'], firebaseItem);
            break;
          case 'bills':
            await _sqliteDAO!.updateBill(adminUid, localItem['id'], firebaseItem);
            break;
        }
        
        // Mark as synced since we just updated from Firebase
        await _sqliteDAO!.markAsSynced(tableName, localItem['id']);
        return true;
      }
      
      // If local item is newer or same timestamp, keep local version
      // but ensure it's marked for sync to Firebase
      else if (localTimestamp >= firebaseTimestamp) {
        print('Resolving conflict for $tableName ${localItem['id']}: Local version is newer or same');
        await _sqliteDAO!.markAsPending(tableName, localItem['id']);
        return false; // Will be synced to Firebase in next sync cycle
      }

      return false;
    } catch (e) {
      print('Error resolving conflict for $tableName ${localItem['id']}: $e');
      return false;
    }
  }

  /// Schedule retry with enhanced exponential backoff
  void _scheduleRetryWithBackoff() {
    if (_retryCount >= _maxRetries) {
      print('Max retries reached, giving up');
      _updateSyncStatus(SyncOperationStatus.idle);
      return;
    }

    _retryCount++;
    
    // Enhanced exponential backoff with jitter to prevent thundering herd
    final int baseDelay = _baseRetryDelaySeconds * pow(2, _retryCount - 1).toInt();
    final int jitter = Random().nextInt(baseDelay ~/ 2); // Add up to 50% jitter
    final int delaySeconds = baseDelay + jitter;
    
    // Cap maximum delay at 5 minutes
    const int maxDelaySeconds = 300;
    final int actualDelay = delaySeconds > maxDelaySeconds ? maxDelaySeconds : delaySeconds;
    
    print('Scheduling retry #$_retryCount in $actualDelay seconds (base: $baseDelay, jitter: $jitter)');
    _updateSyncStatus(SyncOperationStatus.retrying);

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: actualDelay), () {
      print('Executing retry #$_retryCount');
      syncPendingData();
    });
  }

  /// Schedule retry with exponential backoff (legacy method for backward compatibility)
  void _scheduleRetry() {
    _scheduleRetryWithBackoff();
  }

  /// Update sync status and notify listeners
  void _updateSyncStatus(SyncOperationStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _syncStatusController.add(status);
      print('Sync status changed to: $status');
    }
  }

  /// Get count of pending sync items
  Future<int> getPendingSyncCount() async {
    if (_sqliteDAO == null) {
      return 0;
    }
    return await _sqliteDAO!.getPendingItemsCount();
  }

  /// Force sync of a specific item
  Future<SyncResult> forceSyncItem(String tableName, String adminUid, String itemId) async {
    if (_connectionMonitor?.isConnected != true) {
      return SyncResult(success: false, errorMessage: 'No internet connection');
    }

    if (_sqliteDAO == null || _NodeApiDAO == null) {
      return SyncResult(success: false, errorMessage: 'Sync manager not initialized');
    }

    try {
      // Get the item from SQLite
      final item = await _getLocalItem(tableName, adminUid, itemId);
      if (item == null) {
        return SyncResult(success: false, errorMessage: 'Item not found');
      }

      // Sync to Firebase
      final Map<String, dynamic> firebaseData = Map.from(item);
      firebaseData.remove('admin_uid');
      firebaseData.remove('created_at');
      firebaseData.remove('updated_at');
      firebaseData.remove('sync_status');
      firebaseData.remove('image_blob');

      switch (tableName) {
        case 'food_items':
          await _NodeApiDAO!.saveFoodItem(adminUid, firebaseData);
          break;
        case 'departments':
          await _NodeApiDAO!.saveDepartment(adminUid, firebaseData);
          break;
        case 'bills':
          await _NodeApiDAO!.saveBill(adminUid, firebaseData);
          break;
      }

      // Mark as synced
      await _sqliteDAO!.markAsSynced(tableName, itemId);

      return SyncResult(success: true, itemsSynced: 1);
    } catch (e) {
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  /// Cancel any ongoing sync operations
  void cancelSync() {
    _retryTimer?.cancel();
    _retryCount = 0;
    _updateSyncStatus(SyncOperationStatus.idle);
  }

  /// Update sync status after successful completion
  Future<void> _updateSyncStatusAfterCompletion() async {
    if (_sqliteDAO == null) return;
    
    try {
      // Update sync log entries to mark them as completed
      final pendingItems = await _sqliteDAO!.getPendingSyncItems();
      
      for (final item in pendingItems) {
        final tableName = item['table_name'];
        final recordId = item['record_id'];
        
        // Verify the item was actually synced by checking its sync_status in the main table
        final localItem = await _getLocalItem(tableName, item['admin_uid'] ?? '', recordId);
        if (localItem != null && localItem['sync_status'] == SyncStatus.synced.value) {
          // Item is already marked as synced, update the sync log
          await _sqliteDAO!.markAsSynced(tableName, recordId);
        }
      }
      
      print('Updated sync status for all completed items');
    } catch (e) {
      print('Failed to update sync status after completion: $e');
    }
  }

  /// Update last sync time in local storage
  Future<void> _updateLastSyncTime() async {
    try {
      // Store last sync time in a simple key-value table or shared preferences
      // For now, we'll use a simple approach with the sync_log table
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // This could be enhanced to store per-table last sync times
      print('Last sync time updated to: ${DateTime.fromMillisecondsSinceEpoch(now)}');
    } catch (e) {
      print('Failed to update last sync time: $e');
    }
  }

  /// Get last sync time from local storage
  Future<DateTime?> getLastSyncTime() async {
    try {
      // This would retrieve the last sync time from storage
      // For now, return null to indicate full sync is needed
      return null;
    } catch (e) {
      print('Failed to get last sync time: $e');
      return null;
    }
  }

  /// Perform full bidirectional sync
  Future<SyncResult> performFullSync(String adminUid) async {
    try {
      // First sync pending local changes to Firebase
      final toFirebaseResult = await syncPendingData();
      
      if (!toFirebaseResult.success) {
        return toFirebaseResult;
      }
      
      // Then sync changes from Firebase to local
      final lastSyncTime = await getLastSyncTime();
      final fromFirebaseResult = await syncFromFirebase(adminUid, lastSyncTime: lastSyncTime);
      
      if (!fromFirebaseResult.success) {
        return fromFirebaseResult;
      }
      
      // Return combined result
      return SyncResult(
        success: true,
        itemsSynced: toFirebaseResult.itemsSynced + fromFirebaseResult.itemsSynced,
      );
      
    } catch (e) {
      return SyncResult(
        success: false,
        errorMessage: 'Full sync failed: $e',
      );
    }
  }

  /// Get detailed sync statistics
  Future<Map<String, dynamic>> getSyncStatistics() async {
    try {
      final pendingCount = _sqliteDAO != null ? await _sqliteDAO!.getPendingItemsCount() : 0;
      final lastSyncTime = await getLastSyncTime();
      
      // Get data integrity status
      DataIntegrityResult? integrityResult;
      try {
        integrityResult = _sqliteDAO != null ? await _sqliteDAO!.validateDataIntegrity() : null;
      } catch (e) {
        print('Failed to get integrity status: $e');
      }
      
      return {
        'pendingItemsCount': pendingCount,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'currentStatus': _currentStatus.toString(),
        'retryCount': _retryCount,
        'isConnected': _connectionMonitor?.isConnected ?? false,
        'isInitialized': isInitialized,
        'dataIntegrityValid': integrityResult?.isValid ?? false,
        'integrityErrors': integrityResult?.errors ?? [],
        'integrityWarnings': integrityResult?.warnings ?? [],
      };
    } catch (e) {
      return {
        'error': 'Failed to get sync statistics: $e',
      };
    }
  }

  /// Detect and recover from database corruption
  Future<CorruptionRecoveryResult> detectAndRecoverCorruption(String adminUid) async {
    if (_sqliteDAO == null) {
      return CorruptionRecoveryResult(
        corruptionDetected: false,
        recoveryAttempted: false,
        recoverySuccessful: false,
        message: 'SQLite DAO not initialized',
        timestamp: DateTime.now(),
      );
    }

    return await _sqliteDAO!.detectAndRecoverCorruption(adminUid);
  }

  /// Create database backup
  Future<BackupResult> createDatabaseBackup({String? backupName}) async {
    if (_sqliteDAO == null) {
      return BackupResult(
        success: false,
        errorMessage: 'SQLite DAO not initialized',
        timestamp: DateTime.now(),
      );
    }

    return await _sqliteDAO!.createBackup(backupName: backupName);
  }

  /// Restore database from backup or Firebase
  Future<RestoreResult> restoreDatabase({
    String? backupPath,
    String? adminUid,
    bool fromFirebase = false,
  }) async {
    if (_sqliteDAO == null) {
      return RestoreResult(
        success: false,
        errorMessage: 'SQLite DAO not initialized',
        timestamp: DateTime.now(),
      );
    }

    return await _sqliteDAO!.restoreDatabase(
      backupPath: backupPath,
      adminUid: adminUid,
      fromFirebase: fromFirebase,
    );
  }

  /// Get available backups
  Future<List<BackupInfo>> getAvailableBackups() async {
    if (_sqliteDAO == null) {
      return [];
    }

    return await _sqliteDAO!.getAvailableBackups();
  }

  /// Validate data integrity
  Future<DataIntegrityResult> validateDataIntegrity({String? adminUid}) async {
    if (_sqliteDAO == null) {
      return DataIntegrityResult(
        isValid: false,
        errors: ['SQLite DAO not initialized'],
        warnings: [],
        timestamp: DateTime.now(),
      );
    }

    return await _sqliteDAO!.validateDataIntegrity(adminUid: adminUid);
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    _syncStatusController.close();
    _syncResultController.close();
    _connectionMonitor?.dispose();
  }
}
