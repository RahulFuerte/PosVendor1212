import 'dart:async';
import 'dart:developer' as developer;
import 'connection_monitor.dart';
import 'sqlite_dao.dart';
import 'comprehensive_error_handler.dart';
import 'user_error_service.dart';

/// Enhanced offline manager that ensures seamless offline functionality
class EnhancedOfflineManager {
  static final EnhancedOfflineManager _instance = EnhancedOfflineManager._internal();
  factory EnhancedOfflineManager() => _instance;
  EnhancedOfflineManager._internal();

  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  final SQLiteDAO _sqliteDAO = SQLiteDAO();
  final ComprehensiveErrorHandler _errorHandler = ComprehensiveErrorHandler();
  
  final StreamController<OfflineStatus> _offlineStatusController = StreamController<OfflineStatus>.broadcast();
  
  bool _isInitialized = false;
  OfflineStatus _currentStatus = OfflineStatus(
    isOffline: true,
    pendingItemsCount: 0,
    lastSyncTime: null,
    availableDataTypes: [],
  );

  /// Stream that emits offline status updates
  Stream<OfflineStatus> get offlineStatusStream => _offlineStatusController.stream;

  /// Current offline status
  OfflineStatus get currentStatus => _currentStatus;

  /// Initialize the enhanced offline manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _errorHandler.initialize();
      await _connectionMonitor.initialize();
      await _sqliteDAO.initialize();

      // Listen to connectivity changes
      _connectionMonitor.connectivityStream.listen(_onConnectivityChanged);

      // Initialize offline status
      await _updateOfflineStatus();

      _isInitialized = true;
      developer.log('EnhancedOfflineManager initialized successfully', name: 'OfflineManager');
    } catch (e) {
      developer.log('Error initializing EnhancedOfflineManager: $e', name: 'OfflineManager');
      rethrow;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isConnected) async {
    try {
      await _updateOfflineStatus();
      
      if (isConnected) {
        await _errorHandler.handleInfo(
          component: 'EnhancedOfflineManager',
          message: 'Internet connection restored - switching to online mode',
        );
      } else {
        await _errorHandler.handleWarning(
          component: 'EnhancedOfflineManager',
          message: 'Internet connection lost - switching to offline mode',
          userMessage: 'You are now offline. Your data will be saved locally and synced when connection is restored.',
        );
      }
    } catch (e) {
      developer.log('Error handling connectivity change: $e', name: 'OfflineManager');
    }
  }

  /// Update offline status and notify listeners
  Future<void> _updateOfflineStatus() async {
    try {
      final bool isOffline = !_connectionMonitor.isConnected;
      final int pendingItemsCount = await _sqliteDAO.getPendingItemsCount();
      final List<String> availableDataTypes = await _getAvailableDataTypes();

      _currentStatus = OfflineStatus(
        isOffline: isOffline,
        pendingItemsCount: pendingItemsCount,
        lastSyncTime: _currentStatus.lastSyncTime, // Keep previous sync time
        availableDataTypes: availableDataTypes,
      );

      _offlineStatusController.add(_currentStatus);
    } catch (e) {
      developer.log('Error updating offline status: $e', name: 'OfflineManager');
    }
  }

  /// Get available data types in local database
  Future<List<String>> _getAvailableDataTypes() async {
    try {
      final List<String> availableTypes = [];
      
      // Check if we have food items
      final foodItemsCount = await _sqliteDAO.getFoodItemsCount('dummy_admin');
      if (foodItemsCount > 0) {
        availableTypes.add('food_items');
      }
      
      // Check if we have departments
      final departments = await _sqliteDAO.getDepartments('dummy_admin');
      if (departments.isNotEmpty) {
        availableTypes.add('departments');
      }
      
      // Check if we have bills
      final bills = await _sqliteDAO.getBills('dummy_admin');
      if (bills.isNotEmpty) {
        availableTypes.add('bills');
      }

      return availableTypes;
    } catch (e) {
      developer.log('Error getting available data types: $e', name: 'OfflineManager');
      return [];
    }
  }

  /// Ensure offline data persistence for all operations
  Future<void> ensureOfflineDataPersistence() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Verify SQLite database is accessible
      await _sqliteDAO.getPendingItemsCount();
      
      developer.log('Offline data persistence verified', name: 'OfflineManager');
    } catch (e) {
      await _errorHandler.handleCriticalError(
        component: 'EnhancedOfflineManager',
        message: 'Failed to ensure offline data persistence',
        error: e,
        userMessage: 'There was a problem with offline data storage. Please restart the app.',
      );
      rethrow;
    }
  }

  /// Display offline indicator in UI
  Future<void> displayOfflineIndicator() async {
    if (_currentStatus.isOffline) {
      await _errorHandler.handleWarning(
        component: 'EnhancedOfflineManager',
        message: 'Application is running in offline mode',
        userMessage: 'You are offline. Your changes will be saved locally and synced when connection is restored.',
      );
    }
  }

  /// Load all offline data for immediate access
  Future<Map<String, dynamic>> loadAllOfflineData(String adminUid) async {
    try {
      await ensureOfflineDataPersistence();

      final Map<String, dynamic> offlineData = {};

      // Load food items
      final foodItems = await _sqliteDAO.getFoodItems(adminUid);
      offlineData['food_items'] = foodItems;

      // Load departments
      final departments = await _sqliteDAO.getDepartments(adminUid);
      offlineData['departments'] = departments;

      // Load bills
      final bills = await _sqliteDAO.getBills(adminUid);
      offlineData['bills'] = bills;

      developer.log('Loaded offline data: ${foodItems.length} food items, ${departments.length} departments, ${bills.length} bills', 
                   name: 'OfflineManager');

      return offlineData;
    } catch (e) {
      await _errorHandler.handleRecoverableError(
        component: 'EnhancedOfflineManager',
        message: 'Failed to load offline data',
        error: e,
        userMessage: 'Unable to load offline data. Please check your device storage.',
        errorType: UserErrorType.databaseError,
      );
      rethrow;
    }
  }

  /// Check if specific data is available offline
  Future<bool> isDataAvailableOffline(String dataType, String adminUid) async {
    try {
      switch (dataType) {
        case 'food_items':
          final items = await _sqliteDAO.getFoodItems(adminUid);
          return items.isNotEmpty;
        case 'departments':
          final departments = await _sqliteDAO.getDepartments(adminUid);
          return departments.isNotEmpty;
        case 'bills':
          final bills = await _sqliteDAO.getBills(adminUid);
          return bills.isNotEmpty;
        default:
          return false;
      }
    } catch (e) {
      developer.log('Error checking offline data availability: $e', name: 'OfflineManager');
      return false;
    }
  }

  /// Get offline data statistics
  Future<Map<String, dynamic>> getOfflineDataStatistics(String adminUid) async {
    try {
      final foodItemsCount = await _sqliteDAO.getFoodItemsCount(adminUid);
      final departments = await _sqliteDAO.getDepartments(adminUid);
      final bills = await _sqliteDAO.getBills(adminUid);
      final pendingItemsCount = await _sqliteDAO.getPendingItemsCount();

      return {
        'food_items_count': foodItemsCount,
        'departments_count': departments.length,
        'bills_count': bills.length,
        'pending_sync_count': pendingItemsCount,
        'is_offline': _currentStatus.isOffline,
        'last_sync_time': _currentStatus.lastSyncTime?.toIso8601String(),
        'available_data_types': _currentStatus.availableDataTypes,
      };
    } catch (e) {
      developer.log('Error getting offline data statistics: $e', name: 'OfflineManager');
      return {
        'error': e.toString(),
        'is_offline': _currentStatus.isOffline,
      };
    }
  }

  /// Update last sync time
  void updateLastSyncTime(DateTime syncTime) {
    _currentStatus = OfflineStatus(
      isOffline: _currentStatus.isOffline,
      pendingItemsCount: _currentStatus.pendingItemsCount,
      lastSyncTime: syncTime,
      availableDataTypes: _currentStatus.availableDataTypes,
    );
    _offlineStatusController.add(_currentStatus);
  }

  /// Force refresh offline status
  Future<void> refreshOfflineStatus() async {
    await _updateOfflineStatus();
  }

  /// Dispose resources
  void dispose() {
    _offlineStatusController.close();
    _isInitialized = false;
  }
}

/// Offline status data class
class OfflineStatus {
  final bool isOffline;
  final int pendingItemsCount;
  final DateTime? lastSyncTime;
  final List<String> availableDataTypes;

  const OfflineStatus({
    required this.isOffline,
    required this.pendingItemsCount,
    required this.lastSyncTime,
    required this.availableDataTypes,
  });

  @override
  String toString() {
    return 'OfflineStatus(isOffline: $isOffline, pendingItems: $pendingItemsCount, lastSync: $lastSyncTime, dataTypes: $availableDataTypes)';
  }
}