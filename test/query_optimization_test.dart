import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/view/tab_screen/view-model/backend/query_optimization_service.dart';
import '../lib/view/tab_screen/view-model/backend/connection_pool_service.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Query Optimization Service Tests', () {
    test('should create instance successfully', () async {
      final queryOptimizer = QueryOptimizationService();
      expect(queryOptimizer, isNotNull);
    });

    test('should create connection pool successfully', () async {
      final connectionPool = ConnectionPoolService();
      expect(connectionPool, isNotNull);
    });

  });
}