import 'package:flutter/material.dart';
import 'smart_database_service.dart';

/// Example of how to use SmartDatabaseService in your existing code
/// This replaces direct Firebase/SQLite calls with smart online/offline handling
class SmartDatabaseUsageExample {
  final SmartDatabaseService _smartDB = SmartDatabaseService();
  
  /// Initialize the service (call this in your app startup)
  Future<void> initializeDatabase() async {
    try {
      await _smartDB.initialize();
      print('Smart database service initialized successfully');
    } catch (e) {
      print('Failed to initialize smart database service: $e');
      // Handle initialization error - maybe show error dialog
    }
  }

  /// Example: Load food items for ProductDashboard
  /// This automatically handles online/offline scenarios
  Future<List<Map<String, dynamic>>> loadFoodItemsForDashboard(String adminUid, {String? department}) async {
    try {
      // This single call handles:
      // - Online: Gets from Firebase and caches locally
      // - Offline: Gets from local SQLite database
      // - Fixes database_closed errors automatically
      final foodItems = await _smartDB.getFoodItems(adminUid, department: department);
      
      print('Loaded ${foodItems.length} food items (Online: ${_smartDB.isOnline})');
      return foodItems;
    } catch (e) {
      print('Error loading food items: $e');
      // Show user-friendly error message
      throw e;
    }
  }

  /// Example: Save a new food item
  /// This automatically handles online/offline scenarios
  Future<void> saveNewFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    try {
      // This single call handles:
      // - Online: Saves to Firebase and local database
      // - Offline: Saves to local database, will sync when online
      await _smartDB.saveFoodItem(adminUid, foodItem);
      
      if (_smartDB.isOnline) {
        print('Food item saved online and cached locally');
      } else {
        print('Food item saved offline, will sync when connection is restored');
      }
    } catch (e) {
      print('Error saving food item: $e');
      throw e;
    }
  }

  /// Example: Create a bill (critical POS operation)
  Future<void> createBill(String adminUid, Map<String, dynamic> billData) async {
    try {
      // Critical operation - works both online and offline
      await _smartDB.saveBill(adminUid, billData);
      
      if (_smartDB.isOnline) {
        print('Bill saved online and cached locally');
      } else {
        print('Bill saved offline - will sync when connection is restored');
      }
    } catch (e) {
      print('Critical error saving bill: $e');
      // This is critical for POS operations - handle appropriately
      throw e;
    }
  }

  /// Example: Load all data for a dashboard screen
  Future<Map<String, List<Map<String, dynamic>>>> loadDashboardData(String adminUid) async {
    try {
      // Load all data types at once
      final allData = await _smartDB.getAllUserData(adminUid);
      
      print('Dashboard data loaded:');
      print('- Food Items: ${allData['foodItems']?.length ?? 0}');
      print('- Departments: ${allData['departments']?.length ?? 0}');
      print('- Bills: ${allData['bills']?.length ?? 0}');
      print('- Online Status: ${_smartDB.isOnline}');
      
      return allData;
    } catch (e) {
      print('Error loading dashboard data: $e');
      throw e;
    }
  }

  /// Example: Widget that shows connection status and syncs when online
  Widget buildConnectionStatusWidget() {
    return StreamBuilder<bool>(
      stream: _smartDB.connectivityStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        
        return Container(
          padding: const EdgeInsets.all(8.0),
          color: isOnline ? Colors.green : Colors.orange,
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Online - Data synced' : 'Offline - Using local data',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              if (isOnline) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    try {
                      await _smartDB.syncPendingData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data synced successfully')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e')),
                      );
                    }
                  },
                  child: const Icon(Icons.sync, color: Colors.white, size: 16),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Example: Replace existing Firebase calls
  /// 
  /// OLD CODE:
  /// ```dart
  /// final firebaseService = FirebaseService();
  /// final foodItems = await firebaseService.getFoodItems(adminUid);
  /// ```
  /// 
  /// NEW CODE:
  /// ```dart
  /// final smartDB = SmartDatabaseService();
  /// final foodItems = await smartDB.getFoodItems(adminUid);
  /// ```
  /// 
  /// The new code automatically handles:
  /// - Online: Gets from Firebase and caches locally
  /// - Offline: Gets from local database
  /// - Database connection errors
  /// - Automatic sync when connection is restored

  /// Example: Error handling with user-friendly messages
  Future<void> handleDataOperationWithErrorHandling(String adminUid) async {
    try {
      final foodItems = await _smartDB.getFoodItems(adminUid);
      print('Loaded ${foodItems.length} food items for error handling example');
    } catch (e) {
      // The SmartDatabaseService provides user-friendly error messages
      if (_smartDB.isOnline) {
        // Online error - likely a server issue
        _showErrorDialog('Unable to load data from server. Please try again.');
      } else {
        // Offline error - likely no local data
        _showErrorDialog('No offline data available. Please connect to the internet to download data.');
      }
    }
  }

  void _showErrorDialog(String message) {
    // Show error dialog to user
    print('Error: $message');
  }

  /// Example: Check connection status for debugging
  void debugConnectionStatus() {
    final status = _smartDB.getConnectionStatus();
    print('Connection Status: $status');
  }
}

/// Example: Integration with existing Provider/Bloc pattern
class FoodItemsProvider extends ChangeNotifier {
  final SmartDatabaseService _smartDB = SmartDatabaseService();
  List<Map<String, dynamic>> _foodItems = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get foodItems => _foodItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _smartDB.isOnline;

  Future<void> loadFoodItems(String adminUid, {String? department}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _foodItems = await _smartDB.getFoodItems(adminUid, department: department);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _foodItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    try {
      await _smartDB.saveFoodItem(adminUid, foodItem);
      // Reload data to reflect changes
      await loadFoodItems(adminUid);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Example: Search food items with FTS5 fallback handling
  /// This automatically uses FTS5 if available, otherwise falls back to LIKE queries
  Future<List<Map<String, dynamic>>> searchFoodItemsExample(String adminUid, String searchTerm, {String? department}) async {
    try {
      // Check search capabilities first
      final capabilities = await _smartDB.getSearchCapabilities();
      final searchType = capabilities['searchType'] ?? 'Unknown';
      
      print('Using $searchType search for: "$searchTerm"');
      
      // Perform search - automatically handles FTS5/fallback
      final results = await _smartDB.searchFoodItems(
        adminUid, 
        searchTerm, 
        department: department,
        limit: 20,
      );
      
      print('Search completed: ${results.length} results found');
      return results;
    } catch (e) {
      print('Search failed: $e');
      // Return empty results instead of throwing
      return [];
    }
  }

  /// Example: Get search capabilities information
  /// Useful for showing users what search features are available
  Future<Map<String, dynamic>> getSearchInfo() async {
    try {
      final capabilities = await _smartDB.getSearchCapabilities();
      
      final info = {
        'searchType': capabilities['searchType'] ?? 'Basic',
        'fts5Available': capabilities['fts5Available'] ?? false,
        'features': capabilities['capabilities'] ?? {},
      };
      
      print('Search capabilities: $info');
      return info;
    } catch (e) {
      print('Error getting search info: $e');
      return {
        'searchType': 'Basic',
        'fts5Available': false,
        'features': {'basicSearch': true},
      };
    }
  }

  /// Example: Perform database maintenance
  /// Call this periodically to optimize database performance
  Future<void> performDatabaseMaintenance() async {
    try {
      print('Starting database maintenance...');
      await _smartDB.performMaintenance();
      print('Database maintenance completed successfully');
    } catch (e) {
      print('Database maintenance failed: $e');
      // Continue - maintenance failure shouldn't break the app
    }
  }

  /// Example: Widget that shows search capabilities to users
  Widget buildSearchCapabilitiesWidget() {
    return FutureBuilder<Map<String, dynamic>>(
      future: getSearchInfo(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final info = snapshot.data!;
          final searchType = info['searchType'] as String;
          final fts5Available = info['fts5Available'] as bool;
          
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Capabilities',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        fts5Available ? Icons.search : Icons.search_off,
                        color: fts5Available ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text('Search Type: $searchType'),
                    ],
                  ),
                  if (!fts5Available) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Using fallback search (LIKE queries)',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Loading search capabilities...'),
          ),
        );
      },
    );
  }

  /// Example: Handle FTS5 initialization errors gracefully
  Future<void> handleFTS5Error() async {
    try {
      // Try to initialize with FTS5
      await _smartDB.initialize();
    } catch (e) {
      if (e.toString().contains('fts5')) {
        print('FTS5 not available, using fallback search');
        // Show user a non-intrusive message
        // The app will continue to work with fallback search
      } else {
        print('Database initialization error: $e');
        // Handle other initialization errors
        rethrow;
      }
    }
  }
}