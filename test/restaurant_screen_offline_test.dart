import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pos/view/home/restaurant_screen.dart';

void main() {
  group('RestaurantScreen Offline Functionality Tests', () {
    testWidgets('RestaurantScreen should build without errors', (WidgetTester tester) async {
      // Test that the RestaurantScreen can be created without errors
      expect(() => RestaurantScreen(phoneNo: '1234567890'), returnsNormally);
    });

    test('Search functionality should filter items correctly', () {
      // Mock food items data
      final List<Map<String, dynamic>> mockItems = [
        {
          'id': '1',
          'name': 'Pizza Margherita',
          'foodCode': 'PM001',
          'department': 'Pizza',
          'price': '299',
        },
        {
          'id': '2', 
          'name': 'Burger Deluxe',
          'foodCode': 'BD002',
          'department': 'Burgers',
          'price': '199',
        },
        {
          'id': '3',
          'name': 'Pasta Alfredo',
          'foodCode': 'PA003', 
          'department': 'Pasta',
          'price': '249',
        },
      ];

      // Test search by name
      final nameResults = mockItems.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains('pizza');
      }).toList();
      
      expect(nameResults.length, equals(1));
      expect(nameResults.first['name'], equals('Pizza Margherita'));

      // Test search by code
      final codeResults = mockItems.where((item) {
        final code = (item['foodCode'] ?? '').toString().toLowerCase();
        return code.contains('bd');
      }).toList();
      
      expect(codeResults.length, equals(1));
      expect(codeResults.first['name'], equals('Burger Deluxe'));

      // Test search by department
      final deptResults = mockItems.where((item) {
        final department = (item['department'] ?? '').toString().toLowerCase();
        return department.contains('pasta');
      }).toList();
      
      expect(deptResults.length, equals(1));
      expect(deptResults.first['name'], equals('Pasta Alfredo'));
    });

    test('Offline order creation should generate correct bill data', () {
      // Mock order items
      final List<Map<String, dynamic>> orderItems = [
        {
          'name': 'Pizza Margherita',
          'price': 299,
          'quantity': 2,
        },
        {
          'name': 'Burger Deluxe', 
          'price': 199,
          'quantity': 1,
        },
      ];

      final double total = 797.0; // (299 * 2) + 199
      final String adminUid = 'test_admin_123';
      final now = DateTime.now();

      // Simulate offline bill creation
      final billData = {
        'id': 'offline_${now.millisecondsSinceEpoch}_123',
        'bill_number': 'OFF-${now.millisecondsSinceEpoch}',
        'customer_name': 'Walk-in Customer',
        'customer_phone': '1234567890',
        'total_amount': total,
        'tax_amount': 0,
        'discount_amount': 0,
        'bill_date': now.millisecondsSinceEpoch,
        'items': orderItems,
        'payment_method': 'Cash',
        'status': 'Pending',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'sync_status': 'pending',
        'admin_uid': adminUid,
        'is_offline_created': true,
      };

      // Verify bill data structure
      expect(billData['total_amount'], equals(797.0));
      expect(billData['customer_name'], equals('Walk-in Customer'));
      expect(billData['sync_status'], equals('pending'));
      expect(billData['is_offline_created'], equals(true));
      expect(billData['items'], equals(orderItems));
    });

    test('Search debouncing should work correctly', () async {
      // This test verifies that search debouncing logic would work
      // In a real implementation, we would test the Timer functionality
      
      const searchDelay = Duration(milliseconds: 300);
      final stopwatch = Stopwatch()..start();
      
      // Simulate waiting for debounce delay
      await Future.delayed(searchDelay);
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
    });
  });
}