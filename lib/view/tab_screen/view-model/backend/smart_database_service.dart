import 'dart:async';
import 'dart:developer' as developer;
import 'database_connection_manager.dart';
import 'connection_monitor.dart';
import 'database_index_manager.dart';
import 'sqlite_helper.dart';

/// Smart Database Service that automatically handles online/offline scenarios
/// 
/// Key Features:
/// - Online: Gets data from Firebase and stores it in local database
/// - Offline: Shows data from local database
/// - Fixes SqfliteDatabaseException (database_closed) errors
/// - Automatic sync when connection is restored
class SmartDatabaseService {
  static final SmartDatabaseService _instance = SmartDatabaseService._internal();
  factory SmartDatabaseService() => _instance;
  SmartDatabaseService._internal();

  DatabaseConnectionManager? _connectionManager;
  ConnectionMonitor? _connectionMonitor;
  DatabaseIndexManager? _indexManager;
  SQLiteHelper? _sqliteHelper;
  bool _isInitialized = false;
  bool _fts5Available = false;

  /// Initialize the smart database service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('Initializing SmartDatabaseService', name: 'SmartDatabaseService');

      // Initialize SQLite helper first
      _sqliteHelper = SQLiteHelper();
      await _sqliteHelper!.database; // Ensure database is created

      // Initialize connection manager
      _connectionManager = DatabaseConnectionManager();
      await _connectionManager!.initialize();

      // Initialize connection monitor
      _connectionMonitor = ConnectionMonitor();
      await _connectionMonitor!.initialize();

      // Initialize index manager with FTS5 fallback handling
      _indexManager = DatabaseIndexManager();
      await _initializeIndexesWithFallback();

      _isInitialized = true;
      developer.log('SmartDatabaseService initialized successfully', name: 'SmartDatabaseService');
    } catch (e) {
      developer.log('Failed to initialize SmartDatabaseService: $e', name: 'SmartDatabaseService');
      rethrow;
    }
  }

  /// Initialize database indexes with FTS5 fallback handling
  Future<void> _initializeIndexesWithFallback() async {
    try {
      developer.log('Initializing database indexes (FTS5 disabled)', name: 'SmartDatabaseService');
      
      // FTS5 is disabled to prevent app hangs
      _fts5Available = false;
      
      developer.log('FTS5 availability: $_fts5Available', name: 'SmartDatabaseService');
      
      // Create performance indexes (will use fallback only)
      await _indexManager!.createPerformanceIndexes();
      
      developer.log('Database indexes initialized successfully', name: 'SmartDatabaseService');
    } catch (e) {
      developer.log('Error initializing indexes: $e', name: 'SmartDatabaseService');
      
      // Ensure we have essential fallback indexes
      try {
        await _createEssentialFallbackIndexes();
        developer.log('Essential fallback indexes created', name: 'SmartDatabaseService');
      } catch (fallbackError) {
        developer.log('Failed to create fallback indexes: $fallbackError', name: 'SmartDatabaseService');
        // Continue without search indexes - basic functionality will still work
      }
    }
  }

  /// Create essential fallback indexes when FTS5 is not available
  Future<void> _createEssentialFallbackIndexes() async {
    final db = await _sqliteHelper!.database;
    
    final essentialIndexes = [
      // Essential food items indexes for search
      'CREATE INDEX IF NOT EXISTS idx_food_items_name_search ON food_items(name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_name ON food_items(admin_uid, name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_department ON food_items(department)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_dept ON food_items(admin_uid, department)',
      
      // Essential department indexes
      'CREATE INDEX IF NOT EXISTS idx_departments_name ON departments(name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_departments_admin_name ON departments(admin_uid, name COLLATE NOCASE)',
      
      // Essential bill indexes
      'CREATE INDEX IF NOT EXISTS idx_bills_admin_date ON bills(admin_uid, bill_date)',
      'CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date)',
    ];
    
    for (final indexSql in essentialIndexes) {
      try {
        await db.execute(indexSql);
      } catch (e) {
        developer.log('Failed to create index: $indexSql - Error: $e', name: 'SmartDatabaseService');
      }
    }
  }

  /// Get food items with automatic online/offline handling
  /// 
  /// Online behavior: Fetches from Firebase and caches locally
  /// Offline behavior: Returns data from local SQLite database
  Future<List<Map<String, dynamic>>> getFoodItems(
    String adminUid, {
    String? department,
  }) async {
    await _ensureInitialized();

    try {
      return await _connectionManager!.getData(
        'food_items',
        adminUid,
        department: department,
      );
    } catch (e) {
      developer.log('Error getting food items: $e', name: 'SmartDatabaseService');
      
      // Show user-friendly message based on connection status
      if (_connectionMonitor?.isConnected == true) {
        throw Exception('Unable to load food items. Please check your connection and try again.');
      } else {
        throw Exception('Offline mode: Showing locally stored food items. Some data may not be up to date.');
      }
    }
  }

  /// Get departments with automatic online/offline handling
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    await _ensureInitialized();

    try {
      return await _connectionManager!.getData('departments', adminUid);
    } catch (e) {
      developer.log('Error getting departments: $e', name: 'SmartDatabaseService');
      
      if (_connectionMonitor?.isConnected == true) {
        throw Exception('Unable to load departments. Please check your connection and try again.');
      } else {
        throw Exception('Offline mode: Showing locally stored departments.');
      }
    }
  }

  /// Get bills with automatic online/offline handling
  Future<List<Map<String, dynamic>>> getBills(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _ensureInitialized();

    try {
      return await _connectionManager!.getData(
        'bills',
        adminUid,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      developer.log('Error getting bills: $e', name: 'SmartDatabaseService');
      
      if (_connectionMonitor?.isConnected == true) {
        throw Exception('Unable to load bills. Please check your connection and try again.');
      } else {
        throw Exception('Offline mode: Showing locally stored bills.');
      }
    }
  }

  /// Save food item with automatic online/offline handling
  /// 
  /// Online behavior: Saves to Firebase and local database
  /// Offline behavior: Saves to local database, syncs when online
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    await _ensureInitialized();

    try {
      await _connectionManager!.saveData('food_items', adminUid, foodItem);
      
      if (_connectionMonitor?.isConnected == true) {
        developer.log('Food item saved online and cached locally', name: 'SmartDatabaseService');
      } else {
        developer.log('Food item saved offline, will sync when connection is restored', name: 'SmartDatabaseService');
      }
    } catch (e) {
      developer.log('Error saving food item: $e', name: 'SmartDatabaseService');
      throw Exception('Failed to save food item. Please try again.');
    }
  }

  /// Save department with automatic online/offline handling
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    await _ensureInitialized();

    try {
      await _connectionManager!.saveData('departments', adminUid, department);
      
      if (_connectionMonitor?.isConnected == true) {
        developer.log('Department saved online and cached locally', name: 'SmartDatabaseService');
      } else {
        developer.log('Department saved offline, will sync when connection is restored', name: 'SmartDatabaseService');
      }
    } catch (e) {
      developer.log('Error saving department: $e', name: 'SmartDatabaseService');
      throw Exception('Failed to save department. Please try again.');
    }
  }

  /// Save bill with automatic online/offline handling
  Future<void> saveBill(String adminUid, Map<String, dynamic> bill) async {
    await _ensureInitialized();

    try {
      await _connectionManager!.saveData('bills', adminUid, bill);
      
      if (_connectionMonitor?.isConnected == true) {
        developer.log('Bill saved online and cached locally', name: 'SmartDatabaseService');
      } else {
        developer.log('Bill saved offline, will sync when connection is restored', name: 'SmartDatabaseService');
      }
    } catch (e) {
      developer.log('Error saving bill: $e', name: 'SmartDatabaseService');
      throw Exception('Failed to save bill. This is critical for POS operations - please contact support if the issue persists.');
    }
  }

  /// Check if the device is currently online
  bool get isOnline => _connectionManager?.isOnline ?? false;

  /// Get connection status stream for UI updates
  Stream<bool>? get connectivityStream => _connectionManager?.connectivityStream;

  /// Force sync all pending data (useful when connection is restored)
  Future<void> syncPendingData() async {
    await _ensureInitialized();

    if (!isOnline) {
      developer.log('Cannot sync - device is offline', name: 'SmartDatabaseService');
      return;
    }

    try {
      await _connectionManager!.forceSyncPendingData();
      developer.log('Pending data synced successfully', name: 'SmartDatabaseService');
    } catch (e) {
      developer.log('Error syncing pending data: $e', name: 'SmartDatabaseService');
      throw Exception('Failed to sync pending data. Please check your connection and try again.');
    }
  }

  /// Search food items with automatic FTS5/fallback handling
  Future<List<Map<String, dynamic>>> searchFoodItems(
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
  }) async {
    await _ensureInitialized();

    try {
      // Use the connection manager's search functionality
      // which will automatically handle FTS5/fallback
      return await _connectionManager!.searchData(
        'food_items',
        adminUid,
        searchTerm,
        department: department,
        limit: limit,
      );
    } catch (e) {
      developer.log('Error searching food items: $e', name: 'SmartDatabaseService');
      
      if (_connectionMonitor?.isConnected == true) {
        throw Exception('Unable to search food items. Please try again.');
      } else {
        throw Exception('Offline search: Limited search functionality available.');
      }
    }
  }

  /// Get search capabilities information
  Future<Map<String, dynamic>> getSearchCapabilities() async {
    await _ensureInitialized();
    
    try {
      return await _indexManager!.getSearchCapabilities();
    } catch (e) {
      developer.log('Error getting search capabilities: $e', name: 'SmartDatabaseService');
      return {
        'fts5Available': false,
        'fts5TablesExist': false,
        'searchType': 'Fallback',
        'error': e.toString(),
      };
    }
  }

  /// Perform database maintenance to optimize performance
  Future<void> performMaintenance() async {
    await _ensureInitialized();
    
    try {
      await _indexManager!.performDatabaseMaintenance();
      developer.log('Database maintenance completed successfully', name: 'SmartDatabaseService');
    } catch (e) {
      developer.log('Error during database maintenance: $e', name: 'SmartDatabaseService');
    }
  }

  /// Get connection status information for debugging
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isOnline': isOnline,
      'isInitialized': _isInitialized,
      'isDatabaseClosed': _connectionManager?.isDatabaseClosed ?? false,
      'fts5Available': _fts5Available,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionManager?.dispose();
    _isInitialized = false;
  }
}

/// Extension methods for easy integration with existing code
extension SmartDatabaseServiceExtension on SmartDatabaseService {
  /// Quick method to get all data for a user (useful for dashboard screens)
  Future<Map<String, List<Map<String, dynamic>>>> getAllUserData(String adminUid) async {
    try {
      final results = await Future.wait([
        getFoodItems(adminUid),
        getDepartments(adminUid),
        getBills(adminUid),
      ]);

      return {
        'foodItems': results[0],
        'departments': results[1],
        'bills': results[2],
      };
    } catch (e) {
      developer.log('Error getting all user data: $e', name: 'SmartDatabaseService');
      rethrow;
    }
  }

  /// Check if specific data is available (useful for UI state management)
  Future<bool> isDataAvailable(String dataType, String adminUid) async {
    try {
      final data = await _connectionManager!.getData(dataType, adminUid);
      return data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}