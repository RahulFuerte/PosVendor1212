import 'package:flutter_test/flutter_test.dart';
import 'package:pos/view/home/userModel.dart';

void main() {
  group('UserModel Tests', () {
    test('should create UserModel with all fields', () {
      final userModel = UserModel(
        userName: 'John Doe',
        details: [
          {'name': 'Pizza', 'price': 299, 'quantity': 2},
          {'name': 'Burger', 'price': 199, 'quantity': 1},
        ],
        totalAmount: 797.0,
        mobileNo: '1234567890',
      );

      expect(userModel.userName, 'John Doe');
      expect(userModel.mobileNo, '1234567890');
      expect(userModel.totalAmount, 797.0);
      expect(userModel.details.length, 2);
      expect(userModel.isValid, true);
      expect(userModel.hasMobileNo, true);
      expect(userModel.displayMobileNo, '1234567890');
      expect(userModel.itemCount, 3);
    });

    test('should create UserModel without mobile number', () {
      final userModel = UserModel(
        userName: 'Jane Doe',
        details: [
          {'name': 'Pizza', 'price': 299, 'quantity': 1},
        ],
        totalAmount: 299.0,
      );

      expect(userModel.userName, 'Jane Doe');
      expect(userModel.mobileNo, null);
      expect(userModel.hasMobileNo, false);
      expect(userModel.displayMobileNo, 'N/A');
      expect(userModel.isValid, true);
    });

    test('should create UserModel from Map', () {
      final map = {
        'userName': 'Test User',
        'details': [
          {'name': 'Item1', 'price': 100, 'quantity': 2},
          {'name': 'Item2', 'price': 200, 'quantity': 1},
        ],
        'totalAmount': 400.0,
        'mobileNo': '9876543210',
      };

      final userModel = UserModel.fromMap(map);

      expect(userModel.userName, 'Test User');
      expect(userModel.mobileNo, '9876543210');
      expect(userModel.totalAmount, 400.0);
      expect(userModel.details.length, 2);
      expect(userModel.itemCount, 3);
    });

    test('should handle invalid data gracefully', () {
      final map = {
        'userName': '',
        'details': [],
        'totalAmount': -100.0,
        'mobileNo': null,
      };

      final userModel = UserModel.fromMap(map);

      expect(userModel.userName, '');
      expect(userModel.mobileNo, null);
      expect(userModel.totalAmount, -100.0);
      expect(userModel.details.length, 0);
      expect(userModel.isValid, false); // Invalid because empty userName and details
      expect(userModel.hasMobileNo, false);
      expect(userModel.displayMobileNo, 'N/A');
    });

    test('should parse different data types correctly', () {
      final map = {
        'userName': 'Test User',
        'details': [
          {'name': 'Item1', 'price': '100', 'quantity': '2'}, // String values
        ],
        'totalAmount': '299.99', // String total
        'mobileNo': 1234567890, // Integer mobile
      };

      final userModel = UserModel.fromMap(map);

      expect(userModel.userName, 'Test User');
      expect(userModel.mobileNo, '1234567890'); // Converted to string
      expect(userModel.totalAmount, 299.99); // Parsed from string
      expect(userModel.details.length, 1);
    });

    test('should convert to Map correctly', () {
      final userModel = UserModel(
        userName: 'Test User',
        details: [
          {'name': 'Pizza', 'price': 299, 'quantity': 2},
        ],
        totalAmount: 598.0,
        mobileNo: '1234567890',
      );

      final map = userModel.toMap();

      expect(map['userName'], 'Test User');
      expect(map['mobileNo'], '1234567890');
      expect(map['totalAmount'], 598.0);
      expect(map['details'], isA<List<Map<String, dynamic>>>());
    });

    test('should handle complex details parsing', () {
      final map = {
        'userName': 'Test User',
        'details': [
          // Mixed map types (simulating Hive storage)
          <dynamic, dynamic>{'name': 'Item1', 'price': 100, 'quantity': 1},
          <String, dynamic>{'name': 'Item2', 'price': 200, 'quantity': 2},
        ],
        'totalAmount': 500.0,
      };

      final userModel = UserModel.fromMap(map);

      expect(userModel.details.length, 2);
      expect(userModel.details[0]['name'], 'Item1');
      expect(userModel.details[1]['name'], 'Item2');
      expect(userModel.itemCount, 3);
    });
  });
}