// Dart imports:
import 'dart:async';
import 'dart:developer' as developer;

// Project imports:
import '../../core/error/comprehensive_error_handler.dart';
import '../../core/network/connection_monitor.dart';
import 'local/sqlite_dao.dart';
import 'remote/firebase_dao.dart';
import 'unified_database_service.dart';

/// Manages database connections and handles the "database_closed" error
/// Implements the core logic: online = Firebase + SQLite cache, offline = SQLite only
class DatabaseConnectionManager {
  static final DatabaseConnectionManager _instance = DatabaseConnectionManager._internal();
  factory DatabaseConnectionManager() => _instance;
  DatabaseConnectionManager._internal();

  UnifiedDatabaseService? _unifiedService;
  ConnectionMonitor? _connectionMonitor;
  SQLiteDAO? _sqliteDAO;
  NodeApiDAO? _NodeApiDAO;
  ComprehensiveErrorHandler? _errorHandler;
  
  bool _isInitialized = false;
  bool _isDatabaseClosed = false;
  StreamSubscription<bool>? _connectivitySubscription;
  
  /// Initialize the database connection manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      developer.log('Initializing DatabaseConnectionManager', name: 'DatabaseConnectionManager');
      
      // Initialize connection monitor FIRST to know online/offline status
      _connectionMonitor = ConnectionMonitor();
      await _connectionMonitor!.initialize();
      
      final bool isCurrentlyOnline = _connectionMonitor!.isConnected;
      developer.log('Connection status: ${isCurrentlyOnline ? "online" : "offline"}', name: 'DatabaseConnectionManager');
      
      // Initialize SQLite DAO FIRST (always needed, fast initialization)
      _sqliteDAO = SQLiteDAO();
      await _sqliteDAO!.initialize();
      developer.log('SQLite DAO initialized', name: 'DatabaseConnectionManager');
      
      // Mark as initialized early so offline queries can proceed
      _isInitialized = true;
      _isDatabaseClosed = false;
      
      // Initialize error handler (non-blocking for offline)
      _errorHandler = ComprehensiveErrorHandler();
      unawaited(_errorHandler!.initialize().catchError((e) {
        developer.log('Error handler init failed: $e', name: 'DatabaseConnectionManager');
      }));
      
      // Only initialize Firebase and unified service if online
      if (isCurrentlyOnline) {
        _NodeApiDAO = NodeApiDAO();
        try {
          await _NodeApiDAO!.initialize().timeout(const Duration(seconds: 5));
        } catch (e) {
          developer.log('Firebase initialization failed: $e', name: 'DatabaseConnectionManager');
        }
        
        _unifiedService = UnifiedDatabaseService();
        try {
          await _unifiedService!.initialize().timeout(const Duration(seconds: 5));
        } catch (e) {
          developer.log('Unified service initialization failed: $e', name: 'DatabaseConnectionManager');
        }
      } else {
        developer.log('Offline mode - skipping Firebase/UnifiedService init', name: 'DatabaseConnectionManager');
      }
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectionMonitor!.connectivityStream.listen(
        _onConnectivityChanged,
        onError: (error) {
          developer.log('Connectivity monitoring error: $error', name: 'DatabaseConnectionManager');
        },
      );
      
      developer.log('DatabaseConnectionManager initialized successfully', name: 'DatabaseConnectionManager');
    } catch (e) {
      developer.log('Failed to initialize DatabaseConnectionManager: $e', name: 'DatabaseConnectionManager');
      rethrow;
    }
  }

  /// Handle connectivity changes and sync data accordingly
  void _onConnectivityChanged(bool isConnected) async {
    try {
      if (isConnected) {
        developer.log('Connection restored - initializing online services', name: 'DatabaseConnectionManager');
        
        // Initialize Firebase and unified service if not already done
        if (_NodeApiDAO == null) {
          _NodeApiDAO = NodeApiDAO();
          try {
            await _NodeApiDAO!.initialize().timeout(const Duration(seconds: 5));
          } catch (e) {
            developer.log('Firebase initialization failed on reconnect: $e', name: 'DatabaseConnectionManager');
          }
        }
        
        if (_unifiedService == null) {
          _unifiedService = UnifiedDatabaseService();
          try {
            await _unifiedService!.initialize().timeout(const Duration(seconds: 5));
          } catch (e) {
            developer.log('Unified service initialization failed on reconnect: $e', name: 'DatabaseConnectionManager');
          }
        }
        
        await _syncFromFirebaseToLocal();
      } else {
        developer.log('Connection lost - switching to offline mode', name: 'DatabaseConnectionManager');
        await _ensureOfflineMode();
      }
    } catch (e) {
      developer.log('Error handling connectivity change: $e', name: 'DatabaseConnectionManager');
    }
  }

  /// Sync data from Firebase to local SQLite when online
  Future<void> _syncFromFirebaseToLocal() async {
    if (!_isInitialized || _unifiedService == null) return;
    
    try {
      // This will be handled by the unified service's sync manager
      await _unifiedService!.syncPendingData();
      developer.log('Data synced from Firebase to local successfully', name: 'DatabaseConnectionManager');
    } catch (e) {
      developer.log('Failed to sync from Firebase to local: $e', name: 'DatabaseConnectionManager');
    }
  }

  /// Ensure offline mode is working properly
  Future<void> _ensureOfflineMode() async {
    if (!_isInitialized || _sqliteDAO == null) return;
    
    try {
      // Verify SQLite is accessible
      await _sqliteDAO!.isOnline();
      developer.log('Offline mode verified - SQLite is accessible', name: 'DatabaseConnectionManager');
    } catch (e) {
      developer.log('Offline mode verification failed: $e', name: 'DatabaseConnectionManager');
      await _handleDatabaseClosedError();
    }
  }

  /// Handle the database_closed error by reinitializing connections
  Future<void> _handleDatabaseClosedError() async {
    try {
      developer.log('Handling database_closed error - reinitializing connections', name: 'DatabaseConnectionManager');
      
      _isDatabaseClosed = true;
      
      // Close existing connections
      await _closeConnections();
      
      // Reinitialize SQLite DAO
      _sqliteDAO = SQLiteDAO();
      await _sqliteDAO!.initialize();
      
      // Reinitialize unified service
      _unifiedService = UnifiedDatabaseService();
      await _unifiedService!.initialize();
      
      _isDatabaseClosed = false;
      
      developer.log('Database connections reinitialized successfully', name: 'DatabaseConnectionManager');
    } catch (e) {
      developer.log('Failed to handle database_closed error: $e', name: 'DatabaseConnectionManager');
      
      if (_errorHandler != null) {
        await _errorHandler!.handleCriticalError(
          component: 'DatabaseConnectionManager',
          message: 'Critical database connection error',
          error: e,
          userMessage: 'Database connection lost. Please restart the app.',
        );
      }
    }
  }

  /// Close all database connections
  Future<void> _closeConnections() async {
    try {
      await _unifiedService?.close();
      await _sqliteDAO?.close();
      await _NodeApiDAO?.close();
    } catch (e) {
      developer.log('Error closing connections: $e', name: 'DatabaseConnectionManager');
    }
  }

  /// Get data with automatic online/offline handling
  /// Online: Get from Firebase and cache locally
  /// Offline: Get from local SQLite
  Future<List<Map<String, dynamic>>> getData(
    String dataType,
    String adminUid, {
    String? department,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _ensureInitialized();
    
    if (_isDatabaseClosed) {
      await _handleDatabaseClosedError();
    }
    
    try {
      final bool isOnline = _connectionMonitor?.isConnected ?? false;
      
      if (isOnline) {
        // Online mode: Get from Firebase and store in local database
        return await _getDataOnline(dataType, adminUid, department: department, startDate: startDate, endDate: endDate);
      } else {
        // Offline mode: Get from local database
        return await _getDataOffline(dataType, adminUid, department: department, startDate: startDate, endDate: endDate);
      }
    } catch (e) {
      developer.log('Error getting data: $e', name: 'DatabaseConnectionManager');
      
      // If there's an error, try to fallback to local data
      try {
        return await _getDataOffline(dataType, adminUid, department: department, startDate: startDate, endDate: endDate);
      } catch (fallbackError) {
        developer.log('Fallback to local data also failed: $fallbackError', name: 'DatabaseConnectionManager');
        throw Exception('Failed to retrieve data from both online and offline sources: $e');
      }
    }
  }

  /// Get data when online (Firebase + local cache)
  Future<List<Map<String, dynamic>>> _getDataOnline(
    String dataType,
    String adminUid, {
    String? department,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_unifiedService == null) {
      throw Exception('Unified database service not initialized');
    }
    
    try {
      switch (dataType) {
        case 'food_items':
          return await _unifiedService!.getFoodItems(adminUid, department: department);
        case 'departments':
          return await _unifiedService!.getDepartments(adminUid);
        case 'bills':
          return await _unifiedService!.getBills(adminUid, startDate: startDate, endDate: endDate);
        default:
          throw Exception('Unsupported data type: $dataType');
      }
    } catch (e) {
      developer.log('Online data retrieval failed for $dataType: $e', name: 'DatabaseConnectionManager');
      rethrow;
    }
  }

  /// Get data when offline (local SQLite only)
  Future<List<Map<String, dynamic>>> _getDataOffline(
    String dataType,
    String adminUid, {
    String? department,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_sqliteDAO == null) {
      throw Exception('SQLite DAO not initialized');
    }
    
    try {
      developer.log('Getting $dataType from local database (offline mode)', name: 'DatabaseConnectionManager');
      
      switch (dataType) {
        case 'food_items':
          return await _sqliteDAO!.getFoodItems(adminUid, department: department);
        case 'departments':
          return await _sqliteDAO!.getDepartments(adminUid);
        case 'bills':
          return await _sqliteDAO!.getBills(adminUid, startDate: startDate, endDate: endDate);
        default:
          throw Exception('Unsupported data type: $dataType');
      }
    } catch (e) {
      developer.log('Offline data retrieval failed for $dataType: $e', name: 'DatabaseConnectionManager');
      rethrow;
    }
  }

  /// Save data with automatic online/offline handling
  Future<void> saveData(
    String dataType,
    String adminUid,
    Map<String, dynamic> data,
  ) async {
    await _ensureInitialized();
    
    if (_isDatabaseClosed) {
      await _handleDatabaseClosedError();
    }
    
    try {
      final bool isOnline = _connectionMonitor?.isConnected ?? false;
      
      // If online and unified service is available, use it
      if (isOnline && _unifiedService != null) {
        switch (dataType) {
          case 'food_items':
            await _unifiedService!.saveFoodItem(adminUid, data);
            break;
          case 'departments':
            await _unifiedService!.saveDepartment(adminUid, data);
            break;
          case 'bills':
            await _unifiedService!.saveBill(adminUid, data);
            break;
          default:
            throw Exception('Unsupported data type: $dataType');
        }
      } else {
        // Offline mode: Save directly to SQLite
        if (_sqliteDAO == null) {
          throw Exception('SQLite DAO not initialized');
        }
        
        developer.log('Saving $dataType offline to SQLite', name: 'DatabaseConnectionManager');
        
        switch (dataType) {
          case 'food_items':
            await _sqliteDAO!.saveFoodItem(adminUid, data);
            break;
          case 'departments':
            await _sqliteDAO!.saveDepartment(adminUid, data);
            break;
          case 'bills':
            await _sqliteDAO!.saveBill(adminUid, data);
            break;
          default:
            throw Exception('Unsupported data type: $dataType');
        }
      }
      
      developer.log('Data saved successfully: $dataType (${isOnline ? "online" : "offline"})', name: 'DatabaseConnectionManager');
    } catch (e) {
      developer.log('Error saving data: $e', name: 'DatabaseConnectionManager');
      rethrow;
    }
  }

  /// Search data with automatic FTS5/fallback handling
  Future<List<Map<String, dynamic>>> searchData(
    String dataType,
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
  }) async {
    await _ensureInitialized();
    
    if (_isDatabaseClosed) {
      await _handleDatabaseClosedError();
    }
    
    try {
      // Search is primarily handled by SQLite DAO which has FTS5 fallback
      switch (dataType) {
        case 'food_items':
          return await _sqliteDAO!.searchFoodItems(
            adminUid,
            searchTerm,
            department: department,
            limit: limit,
          );
        default:
          throw Exception('Search not supported for data type: $dataType');
      }
    } catch (e) {
      developer.log('Error searching data: $e', name: 'DatabaseConnectionManager');
      rethrow;
    }
  }

  /// Check if we're currently online
  bool get isOnline => _connectionMonitor?.isConnected ?? false;

  /// Check if database is closed
  bool get isDatabaseClosed => _isDatabaseClosed;

  /// Get the unified database service instance
  UnifiedDatabaseService? get unifiedService => _unifiedService;

  /// Ensure the manager is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Force sync all pending data when connection is restored
  Future<void> forceSyncPendingData() async {
    await _ensureInitialized();
    
    if (_unifiedService != null && isOnline) {
      try {
        await _unifiedService!.syncPendingData();
        developer.log('Forced sync of pending data completed', name: 'DatabaseConnectionManager');
      } catch (e) {
        developer.log('Failed to force sync pending data: $e', name: 'DatabaseConnectionManager');
      }
    }
  }

  /// Get connectivity stream
  Stream<bool>? get connectivityStream => _connectionMonitor?.connectivityStream;

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionMonitor?.dispose();
    _isInitialized = false;
    _isDatabaseClosed = false;
  }
}
