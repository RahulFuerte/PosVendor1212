import 'dart:developer' as developer;
import 'smart_database_service.dart';

/// Quick fix for SqfliteDatabaseException (database_closed) error
/// 
/// This class provides immediate fixes you can apply to your existing code
/// without major refactoring
class DatabaseErrorFix {
  static final SmartDatabaseService _smartDB = SmartDatabaseService();
  static bool _isInitialized = false;

  /// Initialize the fix (call this once in your app startup)
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _smartDB.initialize();
      _isInitialized = true;
      developer.log('Database error fix initialized', name: 'DatabaseErrorFix');
    } catch (e) {
      developer.log('Failed to initialize database error fix: $e', name: 'DatabaseErrorFix');
    }
  }

  /// Safe wrapper for any database operation
  /// Use this to wrap your existing database calls
  static Future<T> safeExecute<T>(
    Future<T> Function() operation, {
    T? fallbackValue,
    String? operationName,
  }) async {
    await _ensureInitialized();
    
    try {
      return await operation();
    } catch (e) {
      final errorMessage = e.toString();
      
      // Check if it's the database_closed error
      if (errorMessage.contains('database_closed') || 
          errorMessage.contains('DatabaseException')) {
        developer.log('Database closed error detected, attempting recovery', name: 'DatabaseErrorFix');
        
        try {
          // Reinitialize the smart database service
          await _smartDB.initialize();
          
          // Retry the operation
          return await operation();
        } catch (retryError) {
          developer.log('Retry after database recovery failed: $retryError', name: 'DatabaseErrorFix');
          
          if (fallbackValue != null) {
            return fallbackValue;
          }
          rethrow;
        }
      }
      
      // If it's not a database_closed error, just rethrow
      rethrow;
    }
  }

  /// Quick fix for getFoodItems calls
  static Future<List<Map<String, dynamic>>> getFoodItems(
    String adminUid, {
    String? department,
  }) async {
    return await safeExecute(
      () => _smartDB.getFoodItems(adminUid, department: department),
      fallbackValue: <Map<String, dynamic>>[],
      operationName: 'getFoodItems',
    );
  }

  /// Quick fix for getDepartments calls
  static Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    return await safeExecute(
      () => _smartDB.getDepartments(adminUid),
      fallbackValue: <Map<String, dynamic>>[],
      operationName: 'getDepartments',
    );
  }

  /// Quick fix for getBills calls
  static Future<List<Map<String, dynamic>>> getBills(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await safeExecute(
      () => _smartDB.getBills(adminUid, startDate: startDate, endDate: endDate),
      fallbackValue: <Map<String, dynamic>>[],
      operationName: 'getBills',
    );
  }

  /// Quick fix for saveFoodItem calls
  static Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    return await safeExecute(
      () => _smartDB.saveFoodItem(adminUid, foodItem),
      operationName: 'saveFoodItem',
    );
  }

  /// Quick fix for saveDepartment calls
  static Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    return await safeExecute(
      () => _smartDB.saveDepartment(adminUid, department),
      operationName: 'saveDepartment',
    );
  }

  /// Quick fix for saveBill calls
  static Future<void> saveBill(String adminUid, Map<String, dynamic> bill) async {
    return await safeExecute(
      () => _smartDB.saveBill(adminUid, bill),
      operationName: 'saveBill',
    );
  }

  /// Check if device is online
  static bool get isOnline => _smartDB.isOnline;

  /// Get connection status for debugging
  static Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isOnline': _smartDB.isOnline,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}

/// Extension to make it easy to apply the fix to existing code
extension DatabaseErrorFixExtension on Future<dynamic> {
  /// Apply the database error fix to any Future operation
  Future<T> withDatabaseErrorFix<T>({T? fallbackValue}) async {
    return await DatabaseErrorFix.safeExecute<T>(
      () async => await this as T,
      fallbackValue: fallbackValue,
    );
  }
}

/// Example of how to apply the fix to existing code:
/// 
/// OLD CODE (that throws database_closed error):
/// ```dart
/// final foodItems = await sqliteDAO.getFoodItems(adminUid);
/// ```
/// 
/// NEW CODE (with fix applied):
/// ```dart
/// final foodItems = await DatabaseErrorFix.getFoodItems(adminUid);
/// ```
/// 
/// OR using the extension:
/// ```dart
/// final foodItems = await sqliteDAO.getFoodItems(adminUid).withDatabaseErrorFix(fallbackValue: []);
/// ```
/// 
/// The fix automatically:
/// 1. Detects database_closed errors
/// 2. Reinitializes the database connection
/// 3. Retries the operation
/// 4. Handles online/offline scenarios
/// 5. Provides fallback values if needed