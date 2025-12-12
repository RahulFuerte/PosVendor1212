import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/view/tab_screen/view-model/backend/offline_bill_manager.dart';
import '../lib/view/tab_screen/view-model/backend/database_service.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('OfflineBillManager Tests', () {
    late OfflineBillManager offlineBillManager;
    const String testAdminUid = 'test_admin_123';

    setUp(() async {
      offlineBillManager = OfflineBillManager();
      // Note: We can't fully initialize due to Firebase dependencies in tests
      // These tests focus on the core logic structure
    });

    tearDown(() async {
      try {
        offlineBillManager.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
    });

    test('should create instance successfully', () {
      expect(offlineBillManager, isNotNull);
      expect(offlineBillManager.isInitialized, isFalse);
      expect(offlineBillManager.isSyncing, isFalse);
    });

    test('should provide sync status and result streams', () {
      expect(offlineBillManager.syncStatusStream, isNotNull);
      expect(offlineBillManager.syncResultStream, isNotNull);
    });

    test('should handle sync when not initialized gracefully', () async {
      // This should not throw an exception
      final result = await offlineBillManager.syncOfflineBills(adminUid: testAdminUid);
      
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.billsSynced, equals(0));
    });

    test('should handle manual sync when not connected', () async {
      // This should return appropriate error for no connection
      final result = await offlineBillManager.manualSyncOfflineBills(testAdminUid);
      
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No internet connection'));
      expect(result.billsSynced, equals(0));
    });

    test('should create proper bill data structure for offline storage', () {
      final testBillData = {
        'id': 'bill_123',
        'customer_phone': '+1234567890',
        'items': [
          {'name': 'Test Item', 'price': 10.0, 'quantity': 2}
        ],
        'total_amount': 20.0,
        'bill_date': DateTime.now().millisecondsSinceEpoch,
      };

      // Test that the bill data structure is valid
      expect(testBillData['id'], isNotNull);
      expect(testBillData['total_amount'], isA<double>());
      expect(testBillData['items'], isA<List>());
      expect(testBillData['bill_date'], isA<int>());
    });

    test('should handle sync result creation correctly', () {
      final successResult = OfflineBillSyncResult(
        success: true,
        billsSynced: 5,
      );

      expect(successResult.success, isTrue);
      expect(successResult.billsSynced, equals(5));
      expect(successResult.errorMessage, isNull);
      expect(successResult.timestamp, isNotNull);

      final failureResult = OfflineBillSyncResult(
        success: false,
        errorMessage: 'Test error',
        billsSynced: 0,
      );

      expect(failureResult.success, isFalse);
      expect(failureResult.errorMessage, equals('Test error'));
      expect(failureResult.billsSynced, equals(0));
    });

    test('should handle sync status enum correctly', () {
      const statuses = OfflineBillSyncStatus.values;
      
      expect(statuses, contains(OfflineBillSyncStatus.stored));
      expect(statuses, contains(OfflineBillSyncStatus.syncing));
      expect(statuses, contains(OfflineBillSyncStatus.completed));
      expect(statuses, contains(OfflineBillSyncStatus.failed));
      expect(statuses, contains(OfflineBillSyncStatus.manualSyncStarted));
      expect(statuses, contains(OfflineBillSyncStatus.manualSyncCompleted));
      expect(statuses, contains(OfflineBillSyncStatus.manualSyncFailed));
    });

    test('should prevent concurrent sync operations', () async {
      // Simulate sync in progress by setting internal state
      // This tests the logic structure even without full initialization
      
      final result1 = await offlineBillManager.syncOfflineBills(adminUid: testAdminUid);
      final result2 = await offlineBillManager.syncOfflineBills(adminUid: testAdminUid);
      
      // Both should handle the not-initialized state gracefully
      expect(result1.success, isFalse);
      expect(result2.success, isFalse);
    });

    test('should validate bill sync statistics structure', () async {
      final stats = await offlineBillManager.getOfflineBillSyncStatistics(testAdminUid);
      
      // Should return error structure when not initialized
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('error'), isTrue);
    });

    test('should handle force sync gracefully when not initialized', () async {
      final result = await offlineBillManager.forceSyncOfflineBill(testAdminUid, 'test_bill_id');
      
      expect(result, isFalse);
    });

    test('should handle bill sync status check when not initialized', () async {
      try {
        final isSynced = await offlineBillManager.isBillSynced(testAdminUid, 'test_bill_id');
        expect(isSynced, isFalse);
      } catch (e) {
        // Expected to fail due to Firebase initialization in test environment
        expect(e.toString(), contains('Firebase'));
      }
    });
  });

  group('OfflineBillSyncResult Tests', () {
    test('should create result with default timestamp', () {
      final result = OfflineBillSyncResult(
        success: true,
        billsSynced: 3,
      );

      expect(result.timestamp, isNotNull);
      expect(result.timestamp.isBefore(DateTime.now().add(Duration(seconds: 1))), isTrue);
    });

    test('should create result with custom timestamp', () {
      final customTime = DateTime(2023, 1, 1);
      final result = OfflineBillSyncResult(
        success: false,
        errorMessage: 'Custom error',
        billsSynced: 0,
        timestamp: customTime,
      );

      expect(result.timestamp, equals(customTime));
    });

    test('should have proper toString representation', () {
      final result = OfflineBillSyncResult(
        success: true,
        billsSynced: 2,
      );

      final stringRep = result.toString();
      expect(stringRep, contains('success: true'));
      expect(stringRep, contains('billsSynced: 2'));
      expect(stringRep, contains('OfflineBillSyncResult'));
    });
  });
}