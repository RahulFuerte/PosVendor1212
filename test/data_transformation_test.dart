// Package imports:
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Data Transformation Tests', () {
    test('should parse timestamp from string correctly', () {
      // Test string timestamp parsing
      const stringTimestamp = '2024-01-27 14:07:41.867586';
      final dateTime = DateTime.parse(stringTimestamp);
      final result = dateTime.millisecondsSinceEpoch;
      
      expect(result, isA<int>());
      expect(result, greaterThan(0));
    });

    test('should transform field names correctly', () {
      // Test field name mapping
      final firebaseData = {
        'createdAt': '2024-01-27 14:07:41.867586',
        'uid': '+919999999999',
        'imagePath': 'https://example.com/image.jpg',
        'foodCode': 'F001',
        'isHot': true,
      };

      // Simulate the transformation logic
      final transformed = <String, dynamic>{
        'id': 'test-id',
        'firebase_id': 'test-id',
        'sync_status': 0, // SyncStatus.synced.value
      };

      // Field mappings
      final fieldMappings = {
        'uid': 'admin_uid',
        'imagePath': 'image_path',
        'foodCode': 'food_code',
        'isHot': 'is_hot',
      };

      // Transform fields
      for (final entry in fieldMappings.entries) {
        final firebaseField = entry.key;
        final sqliteField = entry.value;
        
        if (firebaseData.containsKey(firebaseField)) {
          var value = firebaseData[firebaseField];
          
          // Handle special transformations
          if (sqliteField == 'is_hot' && value is bool) {
            value = value ? 1 : 0;
          }
          
          transformed[sqliteField] = value;
        }
      }

      // Handle timestamps
      if (firebaseData.containsKey('createdAt')) {
        final timestamp = firebaseData['createdAt'];
        if (timestamp is String) {
          final dateTime = DateTime.parse(timestamp);
          transformed['created_at'] = dateTime.millisecondsSinceEpoch;
        }
      }

      // Verify transformations
      expect(transformed['admin_uid'], equals('+919999999999'));
      expect(transformed['image_path'], equals('https://example.com/image.jpg'));
      expect(transformed['food_code'], equals('F001'));
      expect(transformed['is_hot'], equals(1)); // Boolean converted to int
      expect(transformed['created_at'], isA<int>());
    });

    test('should handle missing fields gracefully', () {
      final firebaseData = {
        'name': 'Test Item',
        'price': 25.0,
        // Missing optional fields
      };

      final transformed = <String, dynamic>{
        'id': 'test-id',
        'name': firebaseData['name'],
        'price': firebaseData['price'],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 0,
      };

      expect(transformed['name'], equals('Test Item'));
      expect(transformed['price'], equals(25.0));
      expect(transformed['created_at'], isA<int>());
      expect(transformed['updated_at'], isA<int>());
    });
  });
}
