import 'dart:async';
import 'dart:convert';
import 'database_service.dart';
import 'sqlite_dao.dart';
import 'firebase_dao.dart';
import 'connection_monitor.dart';

/// Manages offline bill operations and synchronization
class OfflineBillManager {
  static final OfflineBillManager _instance = OfflineBillManager._internal();
  factory OfflineBillManager() => _instance;
  OfflineBillManager._internal();

  SQLiteDAO? _sqliteDAO;
  FirebaseDAO? _firebaseDAO;
  ConnectionMonitor? _connectionMonitor;
  
  StreamSubscription<bool>? _connectivitySubscription;
  
  final StreamController<OfflineBillSyncStatus> _syncStatusController = 
      StreamController<OfflineBillSyncStatus>.broadcast();
  final StreamController<OfflineBillSyncResult> _syncResultController = 
      StreamController<OfflineBillSyncResult>.broadcast();

  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Stream that emits offline bill sync status changes
  Stream<OfflineBillSyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Stream that emits offline bill sync results
  Stream<OfflineBillSyncResult> get syncResultStream => _syncResultController.stream;

  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently syncing offline bills
  bool get isSyncing => _isSyncing;

  /// Initialize the offline bill manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _sqliteDAO = SQLiteDAO();
      _firebaseDAO = FirebaseDAO();
      _connectionMonitor = ConnectionMonitor();
      
      await _connectionMonitor!.initialize();
      await _sqliteDAO!.initialize();
      await _firebaseDAO!.initialize();

      // Listen for connectivity changes and trigger offline bill sync when online
      _connectivitySubscription = _connectionMonitor!.connectivityStream.listen(
        _onConnectivityChanged,
        onError: (error) {
          print('Offline bill manager connectivity error: $error');
        },
      );

      _isInitialized = true;
      print('OfflineBillManager initialized');
    } catch (e) {
      print('Failed to initialize OfflineBillManager: $e');
      _sqliteDAO = null;
      _firebaseDAO = null;
      _connectionMonitor = null;
      rethrow;
    }
  }

  /// Handle connectivity changes - automatically sync offline bills when online
  void _onConnectivityChanged(bool isConnected) {
    if (isConnected && !_isSyncing) {
      print('Connectivity restored, triggering automatic offline bill sync');
      syncOfflineBills();
    }
  }

  /// Store bill offline with pending sync status
  Future<void> storeBillOffline(String adminUid, Map<String, dynamic> billData) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_sqliteDAO == null) {
      throw Exception('SQLite DAO not initialized');
    }

    try {
      // Ensure bill has required fields for offline storage
      final Map<String, dynamic> offlineBill = {
        ...billData,
        'admin_uid': adminUid,
        'sync_status': SyncStatus.pending.value,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      // Ensure items are stored as JSON string
      if (offlineBill['items'] is List) {
        offlineBill['items'] = jsonEncode(offlineBill['items']);
      }

      // Store bill in SQLite with pending sync status
      await _sqliteDAO!.saveBill(adminUid, offlineBill);
      
      print('Bill ${billData['id']} stored offline with pending sync status');
      
      // Emit status update
      _syncStatusController.add(OfflineBillSyncStatus.stored);
      
    } catch (e) {
      print('Failed to store bill offline: $e');
      throw Exception('Failed to store bill offline: $e');
    }
  }

  /// Get all offline bills with pending sync status
  Future<List<Map<String, dynamic>>> getOfflineBills(String adminUid) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_sqliteDAO == null) {
      throw Exception('SQLite DAO not initialized');
    }

    try {
      // Get all bills with pending sync status
      final allBills = await _sqliteDAO!.getBills(adminUid);
      
      final offlineBills = allBills.where((bill) => 
        bill['sync_status'] == SyncStatus.pending.value
      ).toList();
      
      print('Found ${offlineBills.length} offline bills with pending sync status');
      return offlineBills;
      
    } catch (e) {
      print('Failed to get offline bills: $e');
      return [];
    }
  }

  /// Get count of offline bills pending sync
  Future<int> getOfflineBillsCount(String adminUid) async {
    final offlineBills = await getOfflineBills(adminUid);
    return offlineBills.length;
  }

  /// Automatically sync all offline bills when connectivity is restored
  Future<OfflineBillSyncResult> syncOfflineBills({String? adminUid}) async {
    if (_isSyncing) {
      print('Offline bill sync already in progress');
      return OfflineBillSyncResult(
        success: false,
        errorMessage: 'Sync already in progress',
        billsSynced: 0,
      );
    }

    if (_connectionMonitor?.isConnected != true) {
      print('No internet connection, offline bill sync skipped');
      return OfflineBillSyncResult(
        success: false,
        errorMessage: 'No internet connection',
        billsSynced: 0,
      );
    }

    if (!_isInitialized) {
      await initialize();
    }

    if (_sqliteDAO == null || _firebaseDAO == null) {
      return OfflineBillSyncResult(
        success: false,
        errorMessage: 'Manager not initialized',
        billsSynced: 0,
      );
    }

    _isSyncing = true;
    _syncStatusController.add(OfflineBillSyncStatus.syncing);

    try {
      int totalBillsSynced = 0;
      
      // If adminUid is provided, sync only for that admin
      // Otherwise, we need to get all pending bills across all admins
      List<Map<String, dynamic>> offlineBills;
      
      if (adminUid != null) {
        offlineBills = await getOfflineBills(adminUid);
      } else {
        // Get all pending bills from sync_log table
        final pendingSyncItems = await _sqliteDAO!.getPendingSyncItems();
        final billSyncItems = pendingSyncItems.where((item) => 
          item['table_name'] == 'bills'
        ).toList();
        
        offlineBills = [];
        for (final _ in billSyncItems) {
          // We need to get the actual bill data
          // For now, we'll skip this case and require adminUid
          print('Warning: Syncing all bills requires adminUid parameter');
        }
      }

      if (offlineBills.isEmpty) {
        print('No offline bills to sync');
        final result = OfflineBillSyncResult(
          success: true,
          billsSynced: 0,
        );
        
        _syncStatusController.add(OfflineBillSyncStatus.completed);
        _syncResultController.add(result);
        return result;
      }

      print('Starting sync of ${offlineBills.length} offline bills');

      // Sync bills in batches for better performance
      const int batchSize = 5;
      for (int i = 0; i < offlineBills.length; i += batchSize) {
        final end = (i + batchSize < offlineBills.length) ? i + batchSize : offlineBills.length;
        final batch = offlineBills.sublist(i, end);
        
        final List<Future<bool>> batchOperations = [];
        
        for (final bill in batch) {
          batchOperations.add(_syncSingleOfflineBill(bill));
        }
        
        try {
          final results = await Future.wait(batchOperations);
          final successCount = results.where((success) => success).length;
          totalBillsSynced += successCount;
          
          print('Synced batch: $successCount/${batch.length} bills successful');
          
        } catch (e) {
          print('Batch sync failed, trying individual bills: $e');
          
          // Try individual bills if batch fails
          for (final bill in batch) {
            try {
              final success = await _syncSingleOfflineBill(bill);
              if (success) {
                totalBillsSynced++;
              }
            } catch (individualError) {
              print('Failed to sync individual bill ${bill['id']}: $individualError');
            }
          }
        }
      }

      final result = OfflineBillSyncResult(
        success: true,
        billsSynced: totalBillsSynced,
      );

      _syncStatusController.add(OfflineBillSyncStatus.completed);
      _syncResultController.add(result);
      
      print('Offline bill sync completed: $totalBillsSynced bills synced');
      return result;

    } catch (e) {
      print('Offline bill sync failed: $e');
      
      final result = OfflineBillSyncResult(
        success: false,
        errorMessage: e.toString(),
        billsSynced: 0,
      );

      _syncStatusController.add(OfflineBillSyncStatus.failed);
      _syncResultController.add(result);
      
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single offline bill to Firebase
  Future<bool> _syncSingleOfflineBill(Map<String, dynamic> bill) async {
    try {
      final String adminUid = bill['admin_uid'];
      final String billId = bill['id'];
      
      // Prepare bill data for Firebase (remove SQLite-specific fields)
      final Map<String, dynamic> firebaseBillData = Map.from(bill);
      firebaseBillData.remove('admin_uid');
      firebaseBillData.remove('sync_status');
      firebaseBillData.remove('created_at');
      firebaseBillData.remove('updated_at');
      
      // Ensure items are properly formatted for Firebase
      if (firebaseBillData['items'] is String) {
        try {
          firebaseBillData['items'] = jsonDecode(firebaseBillData['items']);
        } catch (e) {
          print('Warning: Could not decode items JSON for bill $billId: $e');
        }
      }

      // Sync to Firebase
      await _firebaseDAO!.saveBill(adminUid, firebaseBillData);
      
      // Update bill status to synced in SQLite
      await _updateBillSyncStatus(adminUid, billId, SyncStatus.synced);
      
      print('Successfully synced offline bill $billId to Firebase');
      return true;
      
    } catch (e) {
      print('Failed to sync offline bill ${bill['id']}: $e');
      return false;
    }
  }

  /// Manual sync functionality for immediate upload of offline bills
  Future<OfflineBillSyncResult> manualSyncOfflineBills(String adminUid) async {
    print('Manual sync triggered for offline bills');
    
    if (_connectionMonitor?.isConnected != true) {
      return OfflineBillSyncResult(
        success: false,
        errorMessage: 'No internet connection available for manual sync',
        billsSynced: 0,
      );
    }
    
    // Use the same sync logic but with manual trigger
    _syncStatusController.add(OfflineBillSyncStatus.manualSyncStarted);
    
    final result = await syncOfflineBills(adminUid: adminUid);
    
    if (result.success) {
      _syncStatusController.add(OfflineBillSyncStatus.manualSyncCompleted);
    } else {
      _syncStatusController.add(OfflineBillSyncStatus.manualSyncFailed);
    }
    
    return result;
  }

  /// Update bill sync status in SQLite
  Future<void> _updateBillSyncStatus(String adminUid, String billId, SyncStatus status) async {
    if (_sqliteDAO == null) return;
    
    try {
      // Update the bill's sync status
      await _sqliteDAO!.updateBill(adminUid, billId, {
        'sync_status': status.value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Also update the sync log
      await _sqliteDAO!.markAsSynced('bills', billId);
      
      print('Updated bill $billId sync status to ${status.name}');
      
    } catch (e) {
      print('Failed to update bill sync status: $e');
    }
  }

  /// Check if a specific bill is synced
  Future<bool> isBillSynced(String adminUid, String billId) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_sqliteDAO == null) return false;
    
    try {
      final bill = await _sqliteDAO!.getBill(adminUid, billId);
      if (bill == null) return false;
      
      return bill['sync_status'] == SyncStatus.synced.value;
    } catch (e) {
      print('Failed to check bill sync status: $e');
      return false;
    }
  }

  /// Get sync statistics for offline bills
  Future<Map<String, dynamic>> getOfflineBillSyncStatistics(String adminUid) async {
    try {
      final offlineBillsCount = await getOfflineBillsCount(adminUid);
      final allBills = await _sqliteDAO?.getBills(adminUid) ?? [];
      final syncedBillsCount = allBills.where((bill) => 
        bill['sync_status'] == SyncStatus.synced.value
      ).length;
      
      return {
        'offlineBillsCount': offlineBillsCount,
        'syncedBillsCount': syncedBillsCount,
        'totalBillsCount': allBills.length,
        'isConnected': _connectionMonitor?.isConnected ?? false,
        'isSyncing': _isSyncing,
      };
    } catch (e) {
      return {
        'error': 'Failed to get sync statistics: $e',
      };
    }
  }

  /// Force sync a specific offline bill
  Future<bool> forceSyncOfflineBill(String adminUid, String billId) async {
    if (_connectionMonitor?.isConnected != true) {
      print('No internet connection for force sync');
      return false;
    }

    if (!_isInitialized) {
      await initialize();
    }

    if (_sqliteDAO == null) return false;
    
    try {
      final bill = await _sqliteDAO!.getBill(adminUid, billId);
      if (bill == null) {
        print('Bill $billId not found for force sync');
        return false;
      }
      
      if (bill['sync_status'] == SyncStatus.synced.value) {
        print('Bill $billId is already synced');
        return true;
      }
      
      return await _syncSingleOfflineBill(bill);
      
    } catch (e) {
      print('Failed to force sync bill $billId: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _syncResultController.close();
    _connectionMonitor?.dispose();
    _isInitialized = false;
  }
}

/// Enum for offline bill sync status
enum OfflineBillSyncStatus {
  stored,
  syncing,
  completed,
  failed,
  manualSyncStarted,
  manualSyncCompleted,
  manualSyncFailed,
}

/// Result of offline bill sync operation
class OfflineBillSyncResult {
  final bool success;
  final String? errorMessage;
  final int billsSynced;
  final DateTime timestamp;

  OfflineBillSyncResult({
    required this.success,
    this.errorMessage,
    required this.billsSynced,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'OfflineBillSyncResult(success: $success, billsSynced: $billsSynced, error: $errorMessage)';
  }
}