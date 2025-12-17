import 'dart:typed_data';
import 'dart:developer' as developer;
import 'database_service.dart';
import 'sqlite_dao.dart';
import 'firebase_dao.dart';
import 'image_cache_service.dart';
import 'sync_manager.dart';
import 'connection_monitor.dart';
import 'offline_bill_manager.dart';
import 'database_migration_service.dart';
import 'sqlite_helper.dart';
import 'comprehensive_error_handler.dart';
import 'user_error_service.dart';
import 'database_index_manager.dart';
import 'enhanced_offline_manager.dart';
import 'query_optimization_service.dart';

/// Exception class for database service errors with meaningful messages
class DatabaseServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;
  final bool isRecoverable;

  DatabaseServiceException(
    this.message, {
    this.operation,
    this.originalError,
    this.isRecoverable = true,
  });

  @override
  String toString() {
    final operationText = operation != null ? ' during $operation' : '';
    return 'DatabaseServiceException$operationText: $message';
  }
}

/// Unified Database Service that combines SQLite and Firebase operations
/// Provides offline-first functionality with automatic synchronization
class UnifiedDatabaseService implements DatabaseService {
  final SQLiteDAO _sqliteDAO = SQLiteDAO();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final SyncManager _syncManager = SyncManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  final OfflineBillManager _offlineBillManager = OfflineBillManager();
  final DatabaseMigrationService _migrationService = DatabaseMigrationService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final ComprehensiveErrorHandler _errorHandler = ComprehensiveErrorHandler();
  final DatabaseIndexManager _indexManager = DatabaseIndexManager();
  final EnhancedOfflineManager _offlineManager = EnhancedOfflineManager();
  final QueryOptimizationService _queryOptimizer = QueryOptimizationService();
  
  bool _isInitialized = false;
  bool _initializationFailed = false;
  String? _lastInitializationError;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (_initializationFailed) {
      throw DatabaseServiceException(
        'Database service initialization previously failed: $_lastInitializationError',
        operation: 'initialize',
        isRecoverable: false,
      );
    }
    
    try {
      // Initialize error handling first
      await _errorHandler.initialize();
      
      // Check if database recreation is needed (for fixing schema issues)
      await _checkAndRecreateDatabase();
      
      await _errorHandler.handleInfo(
        component: 'UnifiedDatabaseService',
        message: 'Starting database service initialization',
      );
      
      // Initialize SQLite first as it's critical for offline functionality
      await _sqliteDAO.initialize();
      await _errorHandler.handleInfo(
        component: 'UnifiedDatabaseService',
        message: 'SQLite DAO initialized successfully',
      );
      
      // Initialize Firebase (may fail if no internet, but that's okay)
      try {
        await _firebaseDAO.initialize();
        await _errorHandler.handleInfo(
          component: 'UnifiedDatabaseService',
          message: 'Firebase DAO initialized successfully',
        );
      } catch (e) {
        await _errorHandler.handleWarning(
          component: 'UnifiedDatabaseService',
          message: 'Firebase DAO initialization failed, continuing with offline mode',
          context: {'error': e.toString()},
          userMessage: 'Running in offline mode. Your data will sync when connection is restored.',
        );
      }
      
      // Initialize supporting services
      await _imageCacheService.initialize();
      await _syncManager.initialize();
      await _offlineBillManager.initialize();
      await _offlineManager.initialize();
      
      // Check and perform any pending migrations
      await _migrationService.checkAndPerformMigrations();
      
      // Create and optimize database indexes for performance
      await _indexManager.createPerformanceIndexes();
      await _indexManager.optimizeQueryPaths();
      await _errorHandler.handleInfo(
        component: 'UnifiedDatabaseService',
        message: 'Database performance indexes created and optimized',
      );
      
      // Initialize query optimization service
      await _queryOptimizer.initialize();
      await _errorHandler.handleInfo(
        component: 'UnifiedDatabaseService',
        message: 'Query optimization service initialized',
      );
      
      _isInitialized = true;
      await _errorHandler.handleInfo(
        component: 'UnifiedDatabaseService',
        message: 'Database service initialized successfully',
      );
      
    } catch (e) {
      _initializationFailed = true;
      _lastInitializationError = e.toString();
      
      await _errorHandler.handleCriticalError(
        component: 'UnifiedDatabaseService',
        message: 'Database service initialization failed',
        error: e,
        userMessage: 'Failed to initialize the database system. Please restart the app.',
      );
      
      throw DatabaseServiceException(
        'Failed to initialize database service. The application may not function properly.',
        operation: 'initialize',
        originalError: e,
        isRecoverable: false,
      );
    }
  }

  @override
  Future<void> close() async {
    try {
      developer.log('Closing UnifiedDatabaseService', name: 'DatabaseService');
      
      await _sqliteDAO.close();
      await _firebaseDAO.close();
      _syncManager.dispose();
      _offlineBillManager.dispose();
      
      _isInitialized = false;
      _initializationFailed = false;
      _lastInitializationError = null;
      
      developer.log('UnifiedDatabaseService closed successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error closing UnifiedDatabaseService: $e', name: 'DatabaseService');
      // Don't throw here as we're cleaning up
    }
  }

  @override
  Future<bool> isOnline() async {
    try {
      return _connectionMonitor.isConnected;
    } catch (e) {
      developer.log('Error checking online status: $e', name: 'DatabaseService');
      // Fallback to offline mode if connectivity check fails
      return false;
    }
  }

  // Food Items operations
  @override
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department}) async {
    await _ensureInitialized();
    
    try {
      // Ensure offline data persistence is working
      await _offlineManager.ensureOfflineDataPersistence();
      
      // Always return from SQLite for immediate response (offline-first approach)
      List<Map<String, dynamic>> localItems = await _sqliteDAO.getFoodItems(adminUid, department: department);
      
      // Check if we're offline
      final bool isOfflineMode = !await isOnline();
      
      if (isOfflineMode) {
        // Offline mode: Display offline indicator and return local data
        await _offlineManager.displayOfflineIndicator();
        developer.log('Offline mode: Returning ${localItems.length} food items from local database', name: 'DatabaseService');
        return localItems;
      }
      
      // Online mode: If local data is empty, try to fetch from Firebase and cache locally
      if (localItems.isEmpty) {
        try {
          developer.log('Fetching food items from Firebase (local cache empty)', name: 'DatabaseService');
          List<Map<String, dynamic>> firebaseItems = await _firebaseDAO.getFoodItems(adminUid, department: department);
          
          // Cache Firebase data locally for offline access
          for (Map<String, dynamic> item in firebaseItems) {
            try {
              await _sqliteDAO.saveFoodItem(adminUid, item);
              await _sqliteDAO.markAsSynced('food_items', item['id']);
            } catch (e) {
              developer.log('Failed to cache food item ${item['id']}: $e', name: 'DatabaseService');
              // Continue with other items
            }
          }
          
          // Preload images for offline access (non-blocking)
          _imageCacheService.preloadImages('food_items', firebaseItems).catchError((e) {
            developer.log('Failed to preload images: $e', name: 'DatabaseService');
          });
          
          // Update offline manager with fresh data
          await _offlineManager.refreshOfflineStatus();
          
          return firebaseItems;
        } catch (e) {
          developer.log('Failed to fetch food items from Firebase: $e', name: 'DatabaseService');
          // Fallback to local data (graceful degradation)
          await _errorHandler.handleWarning(
            component: 'UnifiedDatabaseService',
            message: 'Firebase fetch failed, using local data',
            context: {'error': e.toString()},
            userMessage: 'Using offline data. Some items may not be up to date.',
          );
          return localItems;
        }
      }
      
      // Return local data (we have data and we're online)
      return localItems;
    } catch (e) {
      await _errorHandler.handleRecoverableError(
        component: 'UnifiedDatabaseService',
        message: 'Failed to retrieve food items',
        error: e,
        userMessage: 'Unable to load food items. Using offline data if available.',
        errorType: UserErrorType.databaseError,
      );
      
      // Try to return local data as fallback
      try {
        final fallbackItems = await _sqliteDAO.getFoodItems(adminUid, department: department);
        developer.log('Returning ${fallbackItems.length} items from fallback local data', name: 'DatabaseService');
        return fallbackItems;
      } catch (fallbackError) {
        throw DatabaseServiceException(
          'Failed to retrieve food items from both online and offline sources.',
          operation: 'getFoodItems',
          originalError: e,
        );
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> getFoodItem(String adminUid, String itemId) async {
    await _ensureInitialized();
    
    try {
      // Try local first (offline-first approach)
      Map<String, dynamic>? localItem = await _sqliteDAO.getFoodItem(adminUid, itemId);
      
      if (localItem != null) {
        return localItem;
      }
      
      // If not found locally and online, try Firebase
      if (await isOnline()) {
        try {
          developer.log('Fetching food item $itemId from Firebase (not found locally)', name: 'DatabaseService');
          Map<String, dynamic>? firebaseItem = await _firebaseDAO.getFoodItem(adminUid, itemId);
          
          if (firebaseItem != null) {
            // Cache locally for future offline access
            try {
              await _sqliteDAO.saveFoodItem(adminUid, firebaseItem);
              await _sqliteDAO.markAsSynced('food_items', firebaseItem['id']);
            } catch (e) {
              developer.log('Failed to cache food item $itemId: $e', name: 'DatabaseService');
              // Still return the item even if caching fails
            }
            return firebaseItem;
          }
        } catch (e) {
          developer.log('Failed to fetch food item $itemId from Firebase: $e', name: 'DatabaseService');
          // Fallback to null (item not found)
        }
      }
      
      return null;
    } catch (e) {
      developer.log('Error in getFoodItem: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to retrieve food item. Please try again.',
        operation: 'getFoodItem',
        originalError: e,
      );
    }
  }

  @override
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    await _ensureInitialized();
    
    try {
      // Always save to SQLite first (offline-first approach)
      await _sqliteDAO.saveFoodItem(adminUid, foodItem);
      developer.log('Food item ${foodItem['id']} saved to local database', name: 'DatabaseService');
      
      // If online, try to sync to Firebase immediately
      if (await isOnline()) {
        try {
          await _firebaseDAO.saveFoodItem(adminUid, foodItem);
          await _sqliteDAO.markAsSynced('food_items', foodItem['id']);
          developer.log('Food item ${foodItem['id']} synced to Firebase', name: 'DatabaseService');
        } catch (e) {
          developer.log('Failed to sync food item ${foodItem['id']} to Firebase: $e', name: 'DatabaseService');
          // Firebase sync failed, item remains marked as pending
          // Will be synced later by SyncManager - this is expected behavior
        }
      } else {
        developer.log('Offline mode: Food item ${foodItem['id']} will be synced when connection is restored', name: 'DatabaseService');
      }
    } catch (e) {
      developer.log('Error saving food item: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to save food item. Please check your data and try again.',
        operation: 'saveFoodItem',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, Map<String, dynamic> updates) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'adminUid': adminUid, 'id': itemId}, 'updateFoodItem');
      
      // Always update SQLite first (offline-first approach)
      await _sqliteDAO.updateFoodItem(adminUid, itemId, updates);
      developer.log('Food item $itemId updated in local database', name: 'DatabaseService');
      
      // If online, try to sync to Firebase immediately
      if (await isOnline()) {
        try {
          await _firebaseDAO.updateFoodItem(adminUid, itemId, updates);
          await _sqliteDAO.markAsSynced('food_items', itemId);
          developer.log('Food item $itemId synced to Firebase', name: 'DatabaseService');
        } catch (e) {
          developer.log('Failed to sync food item update to Firebase: $e', name: 'DatabaseService');
          // Firebase sync failed, item remains marked as pending
          // Will be synced later by SyncManager - this is expected behavior
        }
      } else {
        developer.log('Offline mode: Food item $itemId update will be synced when connection is restored', name: 'DatabaseService');
      }
    } catch (e) {
      developer.log('Error updating food item: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to update food item. Please check your data and try again.',
        operation: 'updateFoodItem',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'adminUid': adminUid, 'id': itemId}, 'deleteFoodItem');
      
      // Always delete from SQLite first (offline-first approach)
      await _sqliteDAO.deleteFoodItem(adminUid, itemId);
      developer.log('Food item $itemId deleted from local database', name: 'DatabaseService');
      
      // If online, try to sync to Firebase immediately
      if (await isOnline()) {
        try {
          await _firebaseDAO.deleteFoodItem(adminUid, itemId);
          developer.log('Food item $itemId deletion synced to Firebase', name: 'DatabaseService');
        } catch (e) {
          developer.log('Failed to sync food item deletion to Firebase: $e', name: 'DatabaseService');
          // Firebase sync failed, deletion will be synced later by SyncManager
        }
      } else {
        developer.log('Offline mode: Food item $itemId deletion will be synced when connection is restored', name: 'DatabaseService');
      }
    } catch (e) {
      developer.log('Error deleting food item: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to delete food item. Please try again.',
        operation: 'deleteFoodItem',
        originalError: e,
      );
    }
  }

  // Departments operations
  @override
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    await _ensureInitialized();
    
    // Always return from SQLite for immediate response
    List<Map<String, dynamic>> localDepartments = await _sqliteDAO.getDepartments(adminUid);
    
    // If online and local data is empty, try to fetch from Firebase and cache locally
    if (localDepartments.isEmpty && await isOnline()) {
      try {
        List<Map<String, dynamic>> firebaseDepartments = await _firebaseDAO.getDepartments(adminUid);
        
        // Cache Firebase data locally
        for (Map<String, dynamic> department in firebaseDepartments) {
          await _sqliteDAO.saveDepartment(adminUid, department);
          await _sqliteDAO.markAsSynced('departments', department['id']);
        }
        
        // Preload images for offline access
        await _imageCacheService.preloadImages('departments', firebaseDepartments);
        
        return firebaseDepartments;
      } catch (e) {
        // If Firebase fails, return local data (even if empty)
        return localDepartments;
      }
    }
    
    return localDepartments;
  }

  @override
  Future<Map<String, dynamic>?> getDepartment(String adminUid, String departmentId) async {
    await _ensureInitialized();
    
    // Try local first
    Map<String, dynamic>? localDepartment = await _sqliteDAO.getDepartment(adminUid, departmentId);
    
    if (localDepartment != null) {
      return localDepartment;
    }
    
    // If not found locally and online, try Firebase
    if (await isOnline()) {
      try {
        Map<String, dynamic>? firebaseDepartment = await _firebaseDAO.getDepartment(adminUid, departmentId);
        
        if (firebaseDepartment != null) {
          // Cache locally
          await _sqliteDAO.saveDepartment(adminUid, firebaseDepartment);
          await _sqliteDAO.markAsSynced('departments', firebaseDepartment['id']);
          return firebaseDepartment;
        }
      } catch (e) {
        // Firebase error, return null
      }
    }
    
    return null;
  }

  @override
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    await _ensureInitialized();
    
    // Always save to SQLite first
    await _sqliteDAO.saveDepartment(adminUid, department);
    
    // If online, try to sync to Firebase immediately
    if (await isOnline()) {
      try {
        await _firebaseDAO.saveDepartment(adminUid, department);
        await _sqliteDAO.markAsSynced('departments', department['id']);
      } catch (e) {
        // Firebase sync failed, item remains marked as pending
      }
    }
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, Map<String, dynamic> updates) async {
    await _ensureInitialized();
    
    // Always update SQLite first
    await _sqliteDAO.updateDepartment(adminUid, departmentId, updates);
    
    // If online, try to sync to Firebase immediately
    if (await isOnline()) {
      try {
        await _firebaseDAO.updateDepartment(adminUid, departmentId, updates);
        await _sqliteDAO.markAsSynced('departments', departmentId);
      } catch (e) {
        // Firebase sync failed, item remains marked as pending
      }
    }
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    await _ensureInitialized();
    
    // Always delete from SQLite first
    await _sqliteDAO.deleteDepartment(adminUid, departmentId);
    
    // If online, try to sync to Firebase immediately
    if (await isOnline()) {
      try {
        await _firebaseDAO.deleteDepartment(adminUid, departmentId);
      } catch (e) {
        // Firebase sync failed, deletion will be synced later
      }
    }
  }

  // Bills operations
  @override
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    await _ensureInitialized();
    
    // Always return from SQLite for immediate response
    List<Map<String, dynamic>> localBills = await _sqliteDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
    
    // If online, try to fetch recent bills from Firebase and merge
    if (await isOnline()) {
      try {
        List<Map<String, dynamic>> firebaseBills = await _firebaseDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
        
        // Cache new Firebase bills locally
        for (Map<String, dynamic> bill in firebaseBills) {
          Map<String, dynamic>? existingBill = await _sqliteDAO.getBill(adminUid, bill['id']);
          if (existingBill == null) {
            await _sqliteDAO.saveBill(adminUid, bill);
            await _sqliteDAO.markAsSynced('bills', bill['id']);
          }
        }
        
        // Return updated local bills
        return await _sqliteDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
      } catch (e) {
        // If Firebase fails, return local data
        return localBills;
      }
    }
    
    return localBills;
  }

  @override
  Future<Map<String, dynamic>?> getBill(String adminUid, String billId) async {
    await _ensureInitialized();
    
    // Try local first
    Map<String, dynamic>? localBill = await _sqliteDAO.getBill(adminUid, billId);
    
    if (localBill != null) {
      return localBill;
    }
    
    // If not found locally and online, try Firebase
    if (await isOnline()) {
      try {
        Map<String, dynamic>? firebaseBill = await _firebaseDAO.getBill(adminUid, billId);
        
        if (firebaseBill != null) {
          // Cache locally
          await _sqliteDAO.saveBill(adminUid, firebaseBill);
          await _sqliteDAO.markAsSynced('bills', firebaseBill['id']);
          return firebaseBill;
        }
      } catch (e) {
        // Firebase error, return null
      }
    }
    
    return null;
  }

  @override
  Future<void> saveBill(String adminUid, Map<String, dynamic> billData) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'adminUid': adminUid, 'id': billData['id']}, 'saveBill');
      
      // Validate bill data
      if (billData['total_amount'] == null || billData['items'] == null) {
        throw DatabaseServiceException(
          'Bill data is incomplete. Total amount and items are required.',
          operation: 'saveBill',
          isRecoverable: false,
        );
      }
      
      // Check if we're online or offline
      final bool isConnected = await isOnline();
      
      if (isConnected) {
        // Online: Try to save to both SQLite and Firebase
        await _sqliteDAO.saveBill(adminUid, billData);
        developer.log('Bill ${billData['id']} saved to local database', name: 'DatabaseService');
        
        try {
          await _firebaseDAO.saveBill(adminUid, billData);
          await _sqliteDAO.markAsSynced('bills', billData['id']);
          developer.log('Bill ${billData['id']} synced to Firebase', name: 'DatabaseService');
        } catch (e) {
          developer.log('Failed to sync bill to Firebase: $e', name: 'DatabaseService');
          // Firebase sync failed, bill remains marked as pending
          // Will be synced later by offline bill manager - this is critical for POS operations
        }
      } else {
        // Offline: Use enhanced offline bill manager for robust offline bill storage
        developer.log('Offline mode: Storing bill ${billData['id']} for later sync', name: 'DatabaseService');
        await _offlineBillManager.storeBillOffline(adminUid, billData);
      }
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      await _errorHandler.handleCriticalError(
        component: 'UnifiedDatabaseService',
        message: 'Critical error saving bill',
        error: e,
        context: {'billId': billData['id'], 'adminUid': adminUid},
        userMessage: 'Failed to save bill. This is critical for POS operations - please contact support immediately.',
      );
      
      throw DatabaseServiceException(
        'Failed to save bill. This is a critical error - please contact support if the issue persists.',
        operation: 'saveBill',
        originalError: e,
        isRecoverable: true,
      );
    }
  }

  @override
  Future<void> updateBill(String adminUid, String billId, Map<String, dynamic> updates) async {
    await _ensureInitialized();
    
    // Always update SQLite first
    await _sqliteDAO.updateBill(adminUid, billId, updates);
    
    // If online, try to sync to Firebase immediately
    if (await isOnline()) {
      try {
        await _firebaseDAO.updateBill(adminUid, billId, updates);
        await _sqliteDAO.markAsSynced('bills', billId);
      } catch (e) {
        // Firebase sync failed, item remains marked as pending
      }
    }
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    await _ensureInitialized();
    
    // Always delete from SQLite first
    await _sqliteDAO.deleteBill(adminUid, billId);
    
    // If online, try to sync to Firebase immediately
    if (await isOnline()) {
      try {
        await _firebaseDAO.deleteBill(adminUid, billId);
      } catch (e) {
        // Firebase sync failed, deletion will be synced later
      }
    }
  }

  // Sync operations
  @override
  Future<void> syncPendingData() async {
    await _ensureInitialized();
    
    try {
      // Delegate to SyncManager for proper sync orchestration
      final result = await _syncManager.syncPendingData();
      
      if (!result.success) {
        throw DatabaseServiceException(
          result.errorMessage ?? 'Sync operation failed for unknown reason',
          operation: 'syncPendingData',
          isRecoverable: true,
        );
      }
      
      developer.log('Sync completed successfully: ${result.itemsSynced} items synced', name: 'DatabaseService');
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      developer.log('Error in syncPendingData: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to synchronize pending data. Please check your connection and try again.',
        operation: 'syncPendingData',
        originalError: e,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    await _ensureInitialized();
    
    try {
      return await _sqliteDAO.getPendingSyncItems();
    } catch (e) {
      developer.log('Error retrieving pending sync items: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to retrieve pending sync items',
        operation: 'getPendingSyncItems',
        originalError: e,
      );
    }
  }

  @override
  Future<void> markAsSynced(String tableName, String recordId) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'id': recordId}, 'markAsSynced', requireAdminUid: false);
      
      if (tableName.isEmpty) {
        throw DatabaseServiceException(
          'Table name is required for sync operations',
          operation: 'markAsSynced',
          isRecoverable: false,
        );
      }
      
      await _sqliteDAO.markAsSynced(tableName, recordId);
      developer.log('Marked $tableName:$recordId as synced', name: 'DatabaseService');
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      developer.log('Error marking item as synced: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to update sync status',
        operation: 'markAsSynced',
        originalError: e,
      );
    }
  }

  @override
  Future<void> markAsPending(String tableName, String recordId) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'id': recordId}, 'markAsPending', requireAdminUid: false);
      
      if (tableName.isEmpty) {
        throw DatabaseServiceException(
          'Table name is required for sync operations',
          operation: 'markAsPending',
          isRecoverable: false,
        );
      }
      
      await _sqliteDAO.markAsPending(tableName, recordId);
      developer.log('Marked $tableName:$recordId as pending sync', name: 'DatabaseService');
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      developer.log('Error marking item as pending: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to update sync status',
        operation: 'markAsPending',
        originalError: e,
      );
    }
  }

  // Image operations
  @override
  Future<Uint8List?> getImageBlob(String tableName, String recordId) async {
    await _ensureInitialized();
    
    try {
      // Validate input parameters specific to image operations
      if (tableName.isEmpty) {
        throw DatabaseServiceException(
          'Table name is required for image operations',
          operation: 'getImageBlob',
          isRecoverable: false,
        );
      }
      
      if (recordId.isEmpty) {
        throw DatabaseServiceException(
          'Record ID is required for image operations',
          operation: 'getImageBlob',
          isRecoverable: false,
        );
      }
      
      return await _imageCacheService.getImageBlob(tableName, recordId);
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      developer.log('Error retrieving image blob: $e', name: 'DatabaseService');
      // Return null for image errors to allow UI to show placeholder
      return null;
    }
  }

  @override
  Future<void> saveImageBlob(String tableName, String recordId, String imageUrl, Uint8List imageData) async {
    await _ensureInitialized();
    
    try {
      // Validate input parameters specific to image operations
      if (tableName.isEmpty) {
        throw DatabaseServiceException(
          'Table name is required for image operations',
          operation: 'saveImageBlob',
          isRecoverable: false,
        );
      }
      
      if (recordId.isEmpty) {
        throw DatabaseServiceException(
          'Record ID is required for image operations',
          operation: 'saveImageBlob',
          isRecoverable: false,
        );
      }
      
      if (imageUrl.isEmpty) {
        throw DatabaseServiceException(
          'Image URL is required for image operations',
          operation: 'saveImageBlob',
          isRecoverable: false,
        );
      }
      
      if (imageData.isEmpty) {
        throw DatabaseServiceException(
          'Image data cannot be empty',
          operation: 'saveImageBlob',
          isRecoverable: false,
        );
      }
      
      await _imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
      developer.log('Image blob saved for $tableName:$recordId', name: 'DatabaseService');
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      developer.log('Error saving image blob: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to save image. Please try again.',
        operation: 'saveImageBlob',
        originalError: e,
      );
    }
  }

  @override
  Future<void> clearImageCache() async {
    await _ensureInitialized();
    
    try {
      await _imageCacheService.clearImageCache();
      developer.log('Image cache cleared successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error clearing image cache: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to clear image cache. Please try again.',
        operation: 'clearImageCache',
        originalError: e,
      );
    }
  }

  // Additional image cache methods
  @override
  Future<Uint8List?> downloadAndCacheImage(String imageUrl, {String? tableName, String? recordId}) async {
    await _ensureInitialized();
    return await _imageCacheService.downloadAndCacheImage(imageUrl, tableName: tableName, recordId: recordId);
  }

  Future<bool> isImageCached(String tableName, String recordId) async {
    await _ensureInitialized();
    return await _imageCacheService.isImageCached(tableName, recordId);
  }

  Future<void> preloadImages(String tableName, List<Map<String, dynamic>> records) async {
    await _ensureInitialized();
    await _imageCacheService.preloadImages(tableName, records);
  }

  Future<Map<String, dynamic>> getImageCacheStatistics() async {
    await _ensureInitialized();
    return await _imageCacheService.getCacheStatistics();
  }

  Future<void> performImageCacheCleanup() async {
    await _ensureInitialized();
    await _imageCacheService.performAutomaticCleanup();
  }

  // Helper methods
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      if (_initializationFailed) {
        throw DatabaseServiceException(
          'Database service is not available. Please restart the application.',
          operation: 'ensureInitialized',
          isRecoverable: false,
        );
      }
      
      try {
        await initialize();
      } catch (e) {
        throw DatabaseServiceException(
          'Failed to initialize database service. The application may not function properly.',
          operation: 'ensureInitialized',
          originalError: e,
          isRecoverable: false,
        );
      }
    }
  }

  /// Provides backward compatibility with existing Firebase-only operations
  /// This method ensures existing code continues to work without modification
  Future<T> _executeWithFallback<T>(
    Future<T> Function() primaryOperation,
    Future<T> Function() fallbackOperation,
    String operationName,
  ) async {
    try {
      return await primaryOperation();
    } catch (e) {
      developer.log('Primary operation failed for $operationName, trying fallback: $e', name: 'DatabaseService');
      
      try {
        return await fallbackOperation();
      } catch (fallbackError) {
        developer.log('Fallback operation also failed for $operationName: $fallbackError', name: 'DatabaseService');
        throw DatabaseServiceException(
          'Both primary and fallback operations failed for $operationName',
          operation: operationName,
          originalError: e,
        );
      }
    }
  }

  /// Validates input parameters to provide meaningful error messages
  void _validateInput(Map<String, dynamic> params, String operation, {bool requireAdminUid = true}) {
    if (requireAdminUid && (params['adminUid'] == null || params['adminUid'].toString().isEmpty)) {
      throw DatabaseServiceException(
        'Admin UID is required for this operation',
        operation: operation,
        isRecoverable: false,
      );
    }

    if (params['id'] != null && params['id'].toString().isEmpty) {
      throw DatabaseServiceException(
        'Item ID cannot be empty',
        operation: operation,
        isRecoverable: false,
      );
    }
  }

  /// Legacy compatibility method for existing Firebase operations
  /// Ensures backward compatibility with existing codebase
  Future<List<Map<String, dynamic>>> getFirebaseData(String collection, String adminUid) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'adminUid': adminUid}, 'getFirebaseData');
      
      // This method provides backward compatibility for existing Firebase calls
      // It routes through the unified service to maintain consistency
      switch (collection) {
        case 'foodItems':
          return await getFoodItems(adminUid);
        case 'departments':
          return await getDepartments(adminUid);
        case 'bills':
          return await getBills(adminUid);
        default:
          throw DatabaseServiceException(
            'Unsupported collection: $collection',
            operation: 'getFirebaseData',
            isRecoverable: false,
          );
      }
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      throw DatabaseServiceException(
        'Failed to retrieve data from collection $collection',
        operation: 'getFirebaseData',
        originalError: e,
      );
    }
  }

  /// Legacy compatibility method for saving data
  Future<void> saveFirebaseData(String collection, String adminUid, Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    try {
      _validateInput({'adminUid': adminUid, 'id': data['id']}, 'saveFirebaseData');
      
      // Route through unified service for consistency
      switch (collection) {
        case 'foodItems':
          await saveFoodItem(adminUid, data);
          break;
        case 'departments':
          await saveDepartment(adminUid, data);
          break;
        case 'bills':
          await saveBill(adminUid, data);
          break;
        default:
          throw DatabaseServiceException(
            'Unsupported collection: $collection',
            operation: 'saveFirebaseData',
            isRecoverable: false,
          );
      }
    } catch (e) {
      if (e is DatabaseServiceException) {
        rethrow;
      }
      
      throw DatabaseServiceException(
        'Failed to save data to collection $collection',
        operation: 'saveFirebaseData',
        originalError: e,
      );
    }
  }

  // Additional utility methods
  Future<int> getPendingItemsCount() async {
    await _ensureInitialized();
    return await _sqliteDAO.getPendingItemsCount();
  }

  Future<List<Map<String, dynamic>>> getPendingItemsByTable(String tableName) async {
    await _ensureInitialized();
    return await _sqliteDAO.getPendingItemsByTable(tableName);
  }

  // Sync Manager integration methods
  
  /// Get sync status stream from SyncManager
  Stream<SyncOperationStatus> get syncStatusStream => _syncManager.syncStatusStream;
  
  /// Get sync result stream from SyncManager
  Stream<SyncResult> get syncResultStream => _syncManager.syncResultStream;
  
  /// Get current sync operation status
  SyncOperationStatus get currentSyncStatus => _syncManager.currentStatus;
  
  /// Get connectivity stream from ConnectionMonitor
  Stream<bool> get connectivityStream => _connectionMonitor.connectivityStream;
  
  /// Sync data from Firebase to local SQLite
  Future<SyncResult> syncFromFirebase(String adminUid) async {
    await _ensureInitialized();
    return await _syncManager.syncFromFirebase(adminUid);
  }
  
  /// Force sync of a specific item
  Future<SyncResult> forceSyncItem(String tableName, String adminUid, String itemId) async {
    await _ensureInitialized();
    return await _syncManager.forceSyncItem(tableName, adminUid, itemId);
  }
  
  /// Get count of pending sync items
  Future<int> getPendingSyncCount() async {
    await _ensureInitialized();
    return await _syncManager.getPendingSyncCount();
  }
  
  /// Cancel any ongoing sync operations
  void cancelSync() {
    _syncManager.cancelSync();
  }

  // Offline Bill Management methods
  
  /// Get all offline bills with pending sync status
  Future<List<Map<String, dynamic>>> getOfflineBills(String adminUid) async {
    await _ensureInitialized();
    return await _offlineBillManager.getOfflineBills(adminUid);
  }
  
  /// Get count of offline bills pending sync
  Future<int> getOfflineBillsCount(String adminUid) async {
    await _ensureInitialized();
    return await _offlineBillManager.getOfflineBillsCount(adminUid);
  }
  
  /// Automatically sync all offline bills when connectivity is restored
  Future<OfflineBillSyncResult> syncOfflineBills(String adminUid) async {
    await _ensureInitialized();
    return await _offlineBillManager.syncOfflineBills(adminUid: adminUid);
  }
  
  /// Manual sync functionality for immediate upload of offline bills
  Future<OfflineBillSyncResult> manualSyncOfflineBills(String adminUid) async {
    await _ensureInitialized();
    return await _offlineBillManager.manualSyncOfflineBills(adminUid);
  }
  
  /// Check if a specific bill is synced
  Future<bool> isBillSynced(String adminUid, String billId) async {
    await _ensureInitialized();
    return await _offlineBillManager.isBillSynced(adminUid, billId);
  }
  
  /// Get sync statistics for offline bills
  Future<Map<String, dynamic>> getOfflineBillSyncStatistics(String adminUid) async {
    await _ensureInitialized();
    return await _offlineBillManager.getOfflineBillSyncStatistics(adminUid);
  }
  
  /// Force sync a specific offline bill
  Future<bool> forceSyncOfflineBill(String adminUid, String billId) async {
    await _ensureInitialized();
    return await _offlineBillManager.forceSyncOfflineBill(adminUid, billId);
  }
  
  /// Get offline bill sync status stream
  Stream<OfflineBillSyncStatus> get offlineBillSyncStatusStream => _offlineBillManager.syncStatusStream;
  
  /// Get offline bill sync result stream
  Stream<OfflineBillSyncResult> get offlineBillSyncResultStream => _offlineBillManager.syncResultStream;

  /// Create a robust offline bill with enhanced conflict resolution
  Future<Map<String, dynamic>> createRobustOfflineBill({
    required String adminUid,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    double? taxAmount,
    double? discountAmount,
  }) async {
    await _ensureInitialized();
    return await _offlineBillManager.createRobustOfflineBill(
      adminUid: adminUid,
      items: items,
      totalAmount: totalAmount,
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMethod: paymentMethod,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
    );
  }

  /// Get detailed offline bill statistics with enhanced metrics
  Future<Map<String, dynamic>> getDetailedOfflineBillStatistics(String adminUid) async {
    await _ensureInitialized();
    return await _offlineBillManager.getDetailedOfflineBillStatistics(adminUid);
  }

  // Health check and diagnostics methods

  /// Perform a health check on the database service
  /// Returns a map with status information for troubleshooting
  Future<Map<String, dynamic>> performHealthCheck() async {
    final Map<String, dynamic> healthStatus = {
      'timestamp': DateTime.now().toIso8601String(),
      'isInitialized': _isInitialized,
      'initializationFailed': _initializationFailed,
      'lastInitializationError': _lastInitializationError,
      'isOnline': false,
      'sqliteStatus': 'unknown',
      'firebaseStatus': 'unknown',
      'syncManagerStatus': 'unknown',
      'imageCacheStatus': 'unknown',
      'offlineBillManagerStatus': 'unknown',
    };

    try {
      // Check online status
      healthStatus['isOnline'] = await isOnline();

      // Check SQLite status
      try {
        await _sqliteDAO.getPendingItemsCount();
        healthStatus['sqliteStatus'] = 'healthy';
      } catch (e) {
        healthStatus['sqliteStatus'] = 'error: $e';
      }

      // Check Firebase status (only if online)
      if (healthStatus['isOnline'] == true) {
        try {
          await _firebaseDAO.isOnline();
          healthStatus['firebaseStatus'] = 'healthy';
        } catch (e) {
          healthStatus['firebaseStatus'] = 'error: $e';
        }
      } else {
        healthStatus['firebaseStatus'] = 'offline';
      }

      // Check sync manager status
      try {
        final syncStats = await _syncManager.getSyncStatistics();
        healthStatus['syncManagerStatus'] = 'healthy';
        healthStatus['syncStatistics'] = syncStats;
      } catch (e) {
        healthStatus['syncManagerStatus'] = 'error: $e';
      }

      // Check image cache status
      try {
        final cacheStats = await _imageCacheService.getCacheStatistics();
        healthStatus['imageCacheStatus'] = 'healthy';
        healthStatus['imageCacheStatistics'] = cacheStats;
      } catch (e) {
        healthStatus['imageCacheStatus'] = 'error: $e';
      }

      // Check offline bill manager status
      try {
        // This would need to be implemented in OfflineBillManager
        healthStatus['offlineBillManagerStatus'] = 'healthy';
      } catch (e) {
        healthStatus['offlineBillManagerStatus'] = 'error: $e';
      }

      // Overall health assessment
      final List<String> errors = [];
      if (healthStatus['sqliteStatus'].toString().startsWith('error')) {
        errors.add('SQLite database issues');
      }
      if (healthStatus['firebaseStatus'].toString().startsWith('error')) {
        errors.add('Firebase connectivity issues');
      }
      if (healthStatus['syncManagerStatus'].toString().startsWith('error')) {
        errors.add('Sync manager issues');
      }

      healthStatus['overallHealth'] = errors.isEmpty ? 'healthy' : 'degraded';
      healthStatus['issues'] = errors;

    } catch (e) {
      healthStatus['overallHealth'] = 'critical';
      healthStatus['criticalError'] = e.toString();
    }

    return healthStatus;
  }

  /// Get service statistics for monitoring and debugging
  Future<Map<String, dynamic>> getServiceStatistics() async {
    try {
      await _ensureInitialized();

      final stats = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'isInitialized': _isInitialized,
        'isOnline': await isOnline(),
      };

      // Get sync statistics
      try {
        stats['syncStatistics'] = await _syncManager.getSyncStatistics();
      } catch (e) {
        stats['syncStatisticsError'] = e.toString();
      }

      // Get pending items count
      try {
        stats['pendingItemsCount'] = await _sqliteDAO.getPendingItemsCount();
      } catch (e) {
        stats['pendingItemsCountError'] = e.toString();
      }

      // Get image cache statistics
      try {
        stats['imageCacheStatistics'] = await _imageCacheService.getCacheStatistics();
      } catch (e) {
        stats['imageCacheStatisticsError'] = e.toString();
      }

      return stats;
    } catch (e) {
      return {
        'error': 'Failed to get service statistics: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Reset the service to a clean state (for troubleshooting)
  Future<void> resetService() async {
    try {
      developer.log('Resetting UnifiedDatabaseService', name: 'DatabaseService');
      
      await close();
      _initializationFailed = false;
      _lastInitializationError = null;
      
      await initialize();
      
      developer.log('UnifiedDatabaseService reset completed', name: 'DatabaseService');
    } catch (e) {
      developer.log('Failed to reset UnifiedDatabaseService: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to reset database service. Please restart the application.',
        operation: 'resetService',
        originalError: e,
        isRecoverable: false,
      );
    }
  }

  // Database Migration Methods

  /// Perform incremental data sync from Firebase
  Future<void> performIncrementalSync({DateTime? since}) async {
    await _ensureInitialized();
    
    try {
      await _migrationService.performIncrementalSync(since: since);
      developer.log('Incremental sync completed successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error during incremental sync: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to perform incremental sync. Please check your connection and try again.',
        operation: 'performIncrementalSync',
        originalError: e,
      );
    }
  }

  /// Validate data integrity between local and remote databases
  Future<Map<String, dynamic>> validateDataIntegrity() async {
    await _ensureInitialized();
    
    try {
      return await _migrationService.validateDataIntegrity();
    } catch (e) {
      developer.log('Error validating data integrity: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to validate data integrity',
        operation: 'validateDataIntegrity',
        originalError: e,
      );
    }
  }

  /// Create a backup of the local database
  Future<String?> createDatabaseBackup() async {
    await _ensureInitialized();
    
    try {
      final backupKey = await _migrationService.createDatabaseBackup();
      if (backupKey != null) {
        developer.log('Database backup created: $backupKey', name: 'DatabaseService');
      }
      return backupKey;
    } catch (e) {
      developer.log('Error creating database backup: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to create database backup',
        operation: 'createDatabaseBackup',
        originalError: e,
      );
    }
  }

  /// Restore database from a backup
  Future<bool> restoreFromBackup(String backupKey) async {
    await _ensureInitialized();
    
    try {
      final success = await _migrationService.restoreFromBackup(backupKey);
      if (success) {
        developer.log('Database restored from backup: $backupKey', name: 'DatabaseService');
      } else {
        developer.log('Failed to restore database from backup: $backupKey', name: 'DatabaseService');
      }
      return success;
    } catch (e) {
      developer.log('Error restoring from backup: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to restore database from backup',
        operation: 'restoreFromBackup',
        originalError: e,
      );
    }
  }

  /// Clean up old database backups
  Future<void> cleanupOldBackups({int keepCount = 5}) async {
    await _ensureInitialized();
    
    try {
      await _migrationService.cleanupOldBackups(keepCount: keepCount);
      developer.log('Old backups cleaned up, keeping $keepCount most recent', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error cleaning up old backups: $e', name: 'DatabaseService');
      // Don't throw here as this is a maintenance operation
    }
  }

  /// Force re-migration from Firebase (for data refresh)
  Future<void> forceReMigration() async {
    await _ensureInitialized();
    
    try {
      // Create backup before re-migration
      await createDatabaseBackup();
      
      // Force re-migration through SQLiteHelper
      await _sqliteHelper.forceReMigration();
      
      developer.log('Force re-migration completed successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error during force re-migration: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to perform force re-migration. Your data backup has been preserved.',
        operation: 'forceReMigration',
        originalError: e,
      );
    }
  }

  /// Check if initial migration is complete
  Future<bool> isMigrationComplete() async {
    await _ensureInitialized();
    
    try {
      return await _sqliteHelper.isMigrationComplete();
    } catch (e) {
      developer.log('Error checking migration status: $e', name: 'DatabaseService');
      return false;
    }
  }

  /// Get migration history
  Future<List<Map<String, dynamic>>> getMigrationHistory() async {
    await _ensureInitialized();
    
    try {
      return await _sqliteHelper.getMigrationHistory();
    } catch (e) {
      developer.log('Error getting migration history: $e', name: 'DatabaseService');
      return [];
    }
  }

  /// Check if database recreation is needed and perform it if necessary
  Future<void> _checkAndRecreateDatabase() async {
    try {
      // Force database recreation to fix schema issues
      developer.log('Forcing database recreation to fix schema issues...', name: 'DatabaseService');
      await _sqliteHelper.recreateDatabase();
      developer.log('Database recreated successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error recreating database: $e', name: 'DatabaseService');
      // Don't fail initialization for this, let normal migration handle it
    }
  }

  // Database Performance Optimization Methods

  /// Analyze query performance and get optimization recommendations
  Future<Map<String, dynamic>> analyzeQueryPerformance() async {
    await _ensureInitialized();
    
    try {
      return await _indexManager.getIndexStatistics();
    } catch (e) {
      developer.log('Error analyzing query performance: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to analyze query performance',
        operation: 'analyzeQueryPerformance',
        originalError: e,
      );
    }
  }

  /// Perform database maintenance for optimal performance
  Future<void> performDatabaseMaintenance() async {
    await _ensureInitialized();
    
    try {
      await _indexManager.performDatabaseMaintenance();
      developer.log('Database maintenance completed successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error during database maintenance: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to perform database maintenance',
        operation: 'performDatabaseMaintenance',
        originalError: e,
      );
    }
  }

  /// Update search indexes when data changes
  Future<void> updateSearchIndexes() async {
    await _ensureInitialized();
    
    try {
      await _indexManager.updateSearchIndexes();
      developer.log('Search indexes updated successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error updating search indexes: $e', name: 'DatabaseService');
      // Don't throw here as this is a maintenance operation
    }
  }

  /// Get database index statistics for monitoring
  Future<Map<String, dynamic>> getDatabaseIndexStatistics() async {
    await _ensureInitialized();
    
    try {
      return await _indexManager.getIndexStatistics();
    } catch (e) {
      developer.log('Error getting index statistics: $e', name: 'DatabaseService');
      return {'error': e.toString()};
    }
  }

  /// Optimize database query paths for better performance
  Future<void> optimizeDatabaseQueries() async {
    await _ensureInitialized();
    
    try {
      await _indexManager.optimizeQueryPaths();
      developer.log('Database query optimization completed', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error optimizing database queries: $e', name: 'DatabaseService');
      throw DatabaseServiceException(
        'Failed to optimize database queries',
        operation: 'optimizeDatabaseQueries',
        originalError: e,
      );
    }
  }

  // Enhanced Offline Management Methods

  /// Get offline status stream
  Stream<OfflineStatus> get offlineStatusStream => _offlineManager.offlineStatusStream;

  /// Get current offline status
  OfflineStatus get currentOfflineStatus => _offlineManager.currentStatus;

  /// Check if specific data is available offline
  Future<bool> isDataAvailableOffline(String dataType, String adminUid) async {
    await _ensureInitialized();
    return await _offlineManager.isDataAvailableOffline(dataType, adminUid);
  }

  /// Load all offline data for immediate access
  Future<Map<String, dynamic>> loadAllOfflineData(String adminUid) async {
    await _ensureInitialized();
    return await _offlineManager.loadAllOfflineData(adminUid);
  }

  /// Get offline data statistics
  Future<Map<String, dynamic>> getOfflineDataStatistics(String adminUid) async {
    await _ensureInitialized();
    return await _offlineManager.getOfflineDataStatistics(adminUid);
  }

  /// Ensure all CRUD operations work seamlessly when offline
  Future<void> ensureOfflineOperationsWork(String adminUid) async {
    await _ensureInitialized();
    
    try {
      // Test basic CRUD operations in offline mode
      await _offlineManager.ensureOfflineDataPersistence();
      
      // Verify we can read data
      await _sqliteDAO.getFoodItems(adminUid);
      await _sqliteDAO.getDepartments(adminUid);
      await _sqliteDAO.getBills(adminUid);
      
      developer.log('Offline CRUD operations verified successfully', name: 'DatabaseService');
    } catch (e) {
      await _errorHandler.handleCriticalError(
        component: 'UnifiedDatabaseService',
        message: 'Offline CRUD operations verification failed',
        error: e,
        userMessage: 'There was a problem with offline functionality. Please restart the app.',
      );
      throw DatabaseServiceException(
        'Failed to ensure offline operations work properly',
        operation: 'ensureOfflineOperationsWork',
        originalError: e,
      );
    }
  }

  /// Display offline status indicator
  Future<void> displayOfflineStatusIndicator() async {
    await _ensureInitialized();
    await _offlineManager.displayOfflineIndicator();
  }

  /// Refresh offline status
  Future<void> refreshOfflineStatus() async {
    await _ensureInitialized();
    await _offlineManager.refreshOfflineStatus();
  }
}