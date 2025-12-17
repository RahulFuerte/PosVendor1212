import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/view/tab_screen/view-model/backend/offline_bill_manager.dart';
import '../lib/view/tab_screen/view-model/backend/database_service.dart';
import 'test_database_helper.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Enhanced Offline Bill Manager Tests', () {
    late OfflineBillManager offlineBillManager;
    const String testAdminUid = 'test_admin_123';

    setUp(() async {
      // Initialize test database
      await TestDatabaseHelper.getTestDatabase();
      
      offlineBillManager = OfflineBillManager();
      await offlineBillManager.initialize();
    });

    tearDown(() async {
      offlineBillManager.dispose();
      await TestDatabaseHelper.closeTestDatabase();
    });

    test('should generate unique local bill IDs', () async {
      // Create multiple bills and verify unique IDs
      final bill1 = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [{'name': 'Item 1', 'price': 10.0, 'quantity': 1}],
        totalAmount: 10.0,
      );

      final bill2 = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [{'name': 'Item 2', 'price': 20.0, 'quantity': 1}],
        totalAmount: 20.0,
      );

      expect(bill1['id'], isNotNull);
      expect(bill2['id'], isNotNull);
      expect(bill1['id'], isNot(equals(bill2['id'])));
      expect(bill1['id'].toString().startsWith('LOCAL_'), isTrue);
      expect(bill2['id'].toString().startsWith('LOCAL_'), isTrue);
    });

    test('should store offline bills with enhanced metadata', () async {
      final billData = {
        'customer_name': 'Test Customer',
        'items': [{'name': 'Test Item', 'price': 15.0, 'quantity': 2}],
        'total_amount': 30.0,
      };

      await offlineBillManager.storeBillOffline(testAdminUid, billData);

      final offlineBills = await offlineBillManager.getOfflineBills(testAdminUid);
      expect(offlineBills.length, equals(1));

      final storedBill = offlineBills.first;
      expect(storedBill['offline_created'], equals(true));
      expect(storedBill['local_timestamp'], isNotNull);
      expect(storedBill['sync_status'], equals(SyncStatus.pending.value));
    });

    test('should provide detailed offline bill statistics', () async {
      // Create some test bills
      for (int i = 0; i < 3; i++) {
        await offlineBillManager.storeBillOffline(testAdminUid, {
          'customer_name': 'Customer $i',
          'items': [{'name': 'Item $i', 'price': 10.0 + i, 'quantity': 1}],
          'total_amount': 10.0 + i,
        });
      }

      final stats = await offlineBillManager.getDetailedOfflineBillStatistics(testAdminUid);
      
      expect(stats['offlineBillsCount'], equals(3));
      expect(stats['totalBillsCount'], greaterThanOrEqualTo(3));
      expect(stats['isConnected'], isA<bool>());
      expect(stats['isSyncing'], equals(false));
    });

    test('should create robust offline bills with all required fields', () async {
      final bill = await offlineBillManager.createRobustOfflineBill(
        adminUid: testAdminUid,
        items: [
          {'name': 'Item 1', 'price': 10.0, 'quantity': 2},
          {'name': 'Item 2', 'price': 15.0, 'quantity': 1},
        ],
        totalAmount: 35.0,
        customerName: 'John Doe',
        customerPhone: '1234567890',
        paymentMethod: 'Card',
        taxAmount: 3.5,
        discountAmount: 2.0,
      );

      expect(bill['id'], isNotNull);
      expect(bill['customer_name'], equals('John Doe'));
      expect(bill['customer_phone'], equals('1234567890'));
      expect(bill['payment_method'], equals('Card'));
      expect(bill['total_amount'], equals(35.0));
      expect(bill['tax_amount'], equals(3.5));
      expect(bill['discount_amount'], equals(2.0));
      expect(bill['offline_created'], equals(true));
      expect(bill['sync_status'], equals(SyncStatus.pending.value));
    });

    test('should handle bill ID conflicts by generating new IDs', () async {
      final existingBillData = {
        'id': 'existing_bill_123',
        'customer_name': 'Existing Customer',
        'items': [{'name': 'Existing Item', 'price': 10.0, 'quantity': 1}],
        'total_amount': 10.0,
      };

      // Store first bill
      await offlineBillManager.storeBillOffline(testAdminUid, existingBillData);

      // Try to store another bill with same ID
      final conflictingBillData = {
        'id': 'existing_bill_123', // Same ID
        'customer_name': 'Conflicting Customer',
        'items': [{'name': 'Conflicting Item', 'price': 20.0, 'quantity': 1}],
        'total_amount': 20.0,
      };

      await offlineBillManager.storeBillOffline(testAdminUid, conflictingBillData);

      final offlineBills = await offlineBillManager.getOfflineBills(testAdminUid);
      expect(offlineBills.length, equals(2));

      // Verify that the second bill got a different ID
      final billIds = offlineBills.map((bill) => bill['id']).toList();
      expect(billIds.toSet().length, equals(2)); // All IDs should be unique
    });
  });
}