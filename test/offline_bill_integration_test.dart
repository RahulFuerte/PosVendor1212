import 'package:flutter_test/flutter_test.dart';
import 'package:pos/view/tab_screen/view-model/backend/offline_bill_manager.dart';
import 'package:pos/view/tab_screen/view-model/backend/connection_monitor.dart';

void main() {
  group('Offline Bill Integration Tests', () {
    late OfflineBillManager offlineBillManager;
    const testAdminUid = 'test_admin_123';

    setUp(() async {
      offlineBillManager = OfflineBillManager();
      await offlineBillManager.initialize();
    });

    tearDown(() {
      offlineBillManager.dispose();
    });

    test('Should create robust offline bill with all required fields', () async {
      final bill = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [
          {'name': 'Test Item 1', 'price': 10.0, 'quantity': 2},
          {'name': 'Test Item 2', 'price': 15.0, 'quantity': 1},
        ],
        totalAmount: 35.0,
        customerName: 'Test Customer',
        paymentMethod: 'Cash',
      );

      expect(bill['id'], isNotNull);
      expect(bill['id'].toString().startsWith('LOCAL_'), true);
      expect(bill['admin_uid'], testAdminUid);
      expect(bill['total_amount'], 35.0);
      expect(bill['sync_status'], 'pending');
      expect(bill['offline_created'], true);
      expect(bill['items'], isNotNull);
    });

    test('Should store bill offline with pending sync status', () async {
      final billData = {
        'id': 'TEST_BILL_001',
        'receiptNo': '12345678',
        'items': [
          {'name': 'Item 1', 'price': 10.0, 'quantity': 1}
        ],
        'subTotal': 10.0,
        'date': 'Dec 17, 2024',
      };

      await offlineBillManager.storeBillOffline(testAdminUid, billData);

      final offlineBills = await offlineBillManager.getOfflineBills(testAdminUid);
      expect(offlineBills.length, greaterThan(0));
      
      final storedBill = offlineBills.firstWhere(
        (bill) => bill['receiptNo'] == '12345678',
        orElse: () => {},
      );
      
      expect(storedBill.isNotEmpty, true);
      expect(storedBill['sync_status'], 'pending');
    });

    test('Should get offline bill count', () async {
      final count = await offlineBillManager.getOfflineBillsCount(testAdminUid);
      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });

    test('Should get detailed offline bill statistics', () async {
      final stats = await offlineBillManager.getDetailedOfflineBillStatistics(testAdminUid);
      
      expect(stats, isNotNull);
      expect(stats.containsKey('offlineBillsCount'), true);
      expect(stats.containsKey('syncedBillsCount'), true);
      expect(stats.containsKey('totalBillsCount'), true);
      expect(stats.containsKey('isConnected'), true);
      expect(stats.containsKey('isSyncing'), true);
    });

    test('Should generate unique local bill IDs', () async {
      final bill1 = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [{'name': 'Item', 'price': 10.0, 'quantity': 1}],
        totalAmount: 10.0,
      );

      final bill2 = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [{'name': 'Item', 'price': 10.0, 'quantity': 1}],
        totalAmount: 10.0,
      );

      expect(bill1['id'], isNot(equals(bill2['id'])));
      expect(bill1['id'].toString().startsWith('LOCAL_'), true);
      expect(bill2['id'].toString().startsWith('LOCAL_'), true);
    });

    test('Should handle sync status streams', () async {
      expect(offlineBillManager.syncStatusStream, isNotNull);
      expect(offlineBillManager.syncResultStream, isNotNull);
    });

    test('Should check if bill is synced', () async {
      final billData = {
        'id': 'TEST_SYNC_CHECK',
        'receiptNo': '99999999',
        'items': [{'name': 'Item', 'price': 10.0, 'quantity': 1}],
        'subTotal': 10.0,
      };

      await offlineBillManager.storeBillOffline(testAdminUid, billData);
      
      final isSynced = await offlineBillManager.isBillSynced(
        testAdminUid,
        'TEST_SYNC_CHECK',
      );
      
      // Should not be synced immediately after storing
      expect(isSynced, false);
    });

    test('Should get sync statistics', () async {
      final stats = await offlineBillManager.getOfflineBillSyncStatistics(testAdminUid);
      
      expect(stats, isNotNull);
      expect(stats.containsKey('offlineBillsCount'), true);
      expect(stats.containsKey('syncedBillsCount'), true);
      expect(stats.containsKey('totalBillsCount'), true);
      expect(stats.containsKey('isConnected'), true);
      expect(stats.containsKey('isSyncing'), true);
    });

    test('Should handle initialization state', () {
      expect(offlineBillManager.isInitialized, true);
      expect(offlineBillManager.isSyncing, false);
    });

    test('Should create bill with optional fields', () async {
      final bill = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [{'name': 'Item', 'price': 10.0, 'quantity': 1}],
        totalAmount: 10.0,
        customerName: 'John Doe',
        customerPhone: '1234567890',
        paymentMethod: 'Card',
        taxAmount: 1.0,
        discountAmount: 0.5,
      );

      expect(bill['customer_name'], 'John Doe');
      expect(bill['customer_phone'], '1234567890');
      expect(bill['payment_method'], 'Card');
      expect(bill['tax_amount'], 1.0);
      expect(bill['discount_amount'], 0.5);
    });

    test('Should handle multiple offline bills', () async {
      // Store multiple bills
      for (int i = 0; i < 3; i++) {
        final billData = {
          'id': 'TEST_MULTI_$i',
          'receiptNo': '1000000$i',
          'items': [{'name': 'Item $i', 'price': 10.0 * (i + 1), 'quantity': 1}],
          'subTotal': 10.0 * (i + 1),
        };
        await offlineBillManager.storeBillOffline(testAdminUid, billData);
      }

      final offlineBills = await offlineBillManager.getOfflineBills(testAdminUid);
      expect(offlineBills.length, greaterThanOrEqualTo(3));
    });
  });

  group('Connection Monitor Tests', () {
    late ConnectionMonitor connectionMonitor;

    setUp(() async {
      connectionMonitor = ConnectionMonitor();
      await connectionMonitor.initialize();
    });

    tearDown(() {
      connectionMonitor.dispose();
    });

    test('Should initialize connection monitor', () {
      expect(connectionMonitor.isConnected, isA<bool>());
    });

    test('Should provide connectivity stream', () {
      expect(connectionMonitor.connectivityStream, isNotNull);
    });
  });

  group('Offline Bill Sync Result Tests', () {
    test('Should create sync result with success', () {
      final result = OfflineBillSyncResult(
        success: true,
        billsSynced: 5,
        billsSkipped: 1,
        conflictsResolved: 2,
        syncedBillIds: ['bill1', 'bill2'],
        failedBillIds: ['bill3'],
      );

      expect(result.success, true);
      expect(result.billsSynced, 5);
      expect(result.billsSkipped, 1);
      expect(result.conflictsResolved, 2);
      expect(result.syncedBillIds.length, 2);
      expect(result.failedBillIds.length, 1);
      expect(result.timestamp, isNotNull);
    });

    test('Should create sync result with failure', () {
      final result = OfflineBillSyncResult(
        success: false,
        errorMessage: 'Network error',
        billsSynced: 0,
      );

      expect(result.success, false);
      expect(result.errorMessage, 'Network error');
      expect(result.billsSynced, 0);
    });

    test('Should have toString method', () {
      final result = OfflineBillSyncResult(
        success: true,
        billsSynced: 3,
      );

      final str = result.toString();
      expect(str, contains('success: true'));
      expect(str, contains('synced: 3'));
    });
  });
}
