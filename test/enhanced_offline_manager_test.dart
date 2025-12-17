import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/view/tab_screen/view-model/backend/enhanced_offline_manager.dart';
import '../lib/view/tab_screen/view-model/backend/sqlite_dao.dart';
import '../lib/view/tab_screen/view-model/backend/connection_monitor.dart';

void main() {
  group('Enhanced Offline Manager Tests', () {
    late EnhancedOfflineManager offlineManager;
    late SQLiteDAO sqliteDAO;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      offlineManager = EnhancedOfflineManager();
      sqliteDAO = SQLiteDAO();
      
      // Initialize services
      await sqliteDAO.initialize();
    });

    tearDown(() async {
      offlineManager.dispose();
      await sqliteDAO.close();
    });

    test('should initialize successfully', () async {
      await offlineManager.initialize();
      
      expect(offlineManager.currentStatus, isA<OfflineStatus>());
      expect(offlineManager.currentStatus.isOffline, isTrue); // Should be offline in test environment
    });

    test('should ensure offline data persistence', () async {
      await offlineManager.initialize();
      
      // Should not throw an exception
      await offlineManager.ensureOfflineDataPersistence();
      
      expect(true, isTrue); // Test passes if no exception is thrown
    });

    test('should load offline data successfully', () async {
      const adminUid = 'test_admin';
      await offlineManager.initialize();
      
      // Add some test data
      await sqliteDAO.saveFoodItem(adminUid, {
        'id': 'item_1',
        'name': 'Test Item',
        'price': 10.0,
        'department': 'Test Department',
        'food_code': 'TEST001',
        'description': 'Test description',
        'stocks': 100,
        'is_hot': false,
        'tax': 'GST',
      });
      
      // Load offline data
      final offlineData = await offlineManager.loadAllOfflineData(adminUid);
      
      expect(offlineData, isA<Map<String, dynamic>>());
      expect(offlineData['food_items'], isA<List>());
      expect(offlineData['departments'], isA<List>());
      expect(offlineData['bills'], isA<List>());
      
      final foodItems = offlineData['food_items'] as List;
      expect(foodItems.length, equals(1));
      expect(foodItems.first['name'], equals('Test Item'));
    });

    test('should check data availability offline', () async {
      const adminUid = 'test_admin';
      await offlineManager.initialize();
      
      // Initially no data should be available
      expect(await offlineManager.isDataAvailableOffline('food_items', adminUid), isFalse);
      
      // Add some test data
      await sqliteDAO.saveFoodItem(adminUid, {
        'id': 'item_1',
        'name': 'Test Item',
        'price': 10.0,
        'department': 'Test Department',
        'food_code': 'TEST001',
        'description': 'Test description',
        'stocks': 100,
        'is_hot': false,
        'tax': 'GST',
      });
      
      // Now data should be available
      expect(await offlineManager.isDataAvailableOffline('food_items', adminUid), isTrue);
      expect(await offlineManager.isDataAvailableOffline('departments', adminUid), isFalse);
    });

    test('should get offline data statistics', () async {
      const adminUid = 'test_admin';
      await offlineManager.initialize();
      
      // Add some test data
      await sqliteDAO.saveFoodItem(adminUid, {
        'id': 'item_1',
        'name': 'Test Item 1',
        'price': 10.0,
        'department': 'Test Department',
        'food_code': 'TEST001',
        'description': 'Test description',
        'stocks': 100,
        'is_hot': false,
        'tax': 'GST',
      });
      
      await sqliteDAO.saveFoodItem(adminUid, {
        'id': 'item_2',
        'name': 'Test Item 2',
        'price': 15.0,
        'department': 'Test Department',
        'food_code': 'TEST002',
        'description': 'Test description 2',
        'stocks': 50,
        'is_hot': true,
        'tax': 'GST',
      });
      
      final stats = await offlineManager.getOfflineDataStatistics(adminUid);
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['food_items_count'], equals(2));
      expect(stats['departments_count'], equals(0));
      expect(stats['bills_count'], equals(0));
      expect(stats['is_offline'], isTrue);
      expect(stats['available_data_types'], isA<List>());
      
      print('Offline Statistics: $stats');
    });

    test('should handle offline status updates', () async {
      await offlineManager.initialize();
      
      // Listen to status updates
      final statusUpdates = <OfflineStatus>[];
      final subscription = offlineManager.offlineStatusStream.listen((status) {
        statusUpdates.add(status);
      });
      
      // Refresh status
      await offlineManager.refreshOfflineStatus();
      
      // Wait a bit for the stream to emit
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(statusUpdates.isNotEmpty, isTrue);
      expect(statusUpdates.last.isOffline, isTrue); // Should be offline in test environment
      
      await subscription.cancel();
    });

    test('should update last sync time', () async {
      await offlineManager.initialize();
      
      final syncTime = DateTime.now();
      offlineManager.updateLastSyncTime(syncTime);
      
      expect(offlineManager.currentStatus.lastSyncTime, equals(syncTime));
    });

    test('should handle offline status stream', () async {
      await offlineManager.initialize();
      
      expect(offlineManager.offlineStatusStream, isA<Stream<OfflineStatus>>());
      
      // Test that we can listen to the stream
      final completer = Completer<OfflineStatus>();
      final subscription = offlineManager.offlineStatusStream.listen((status) {
        if (!completer.isCompleted) {
          completer.complete(status);
        }
      });
      
      // Trigger a status update
      await offlineManager.refreshOfflineStatus();
      
      final status = await completer.future.timeout(const Duration(seconds: 2));
      expect(status, isA<OfflineStatus>());
      expect(status.isOffline, isTrue);
      
      await subscription.cancel();
    });

    test('should provide meaningful offline status information', () async {
      await offlineManager.initialize();
      
      final status = offlineManager.currentStatus;
      
      expect(status.isOffline, isA<bool>());
      expect(status.pendingItemsCount, isA<int>());
      expect(status.availableDataTypes, isA<List<String>>());
      
      // Test toString method
      final statusString = status.toString();
      expect(statusString, contains('OfflineStatus'));
      expect(statusString, contains('isOffline'));
      expect(statusString, contains('pendingItems'));
      
      print('Offline Status: $statusString');
    });
  });
}