import 'package:flutter_test/flutter_test.dart';
import 'package:pos/view/tab_screen/view-model/backend/price_utils.dart';

void main() {
  group('Type Conversion Fix Tests', () {
    test('should handle various data types for MenuItem parameters', () {
      // Test price conversion
      expect(PriceUtils.safePriceToString(123), '123');
      expect(PriceUtils.safePriceToString('123'), '123');
      expect(PriceUtils.safePriceToString(123.45), '123.45');
      expect(PriceUtils.safePriceToString(null), '0');
      expect(PriceUtils.safePriceToString(''), '0');
      
      // Test with default values
      expect(PriceUtils.safePriceToString(null, defaultValue: 'N/A'), 'N/A');
      expect(PriceUtils.safePriceToString('', defaultValue: 'N/A'), 'N/A');
    });

    test('should handle foodCode conversion', () {
      // Test various foodCode types
      expect(PriceUtils.safePriceToString('ABC123', defaultValue: 'N/A'), 'ABC123');
      expect(PriceUtils.safePriceToString(123, defaultValue: 'N/A'), '123');
      expect(PriceUtils.safePriceToString(null, defaultValue: 'N/A'), 'N/A');
      expect(PriceUtils.safePriceToString('', defaultValue: 'N/A'), 'N/A');
    });

    test('should handle stocks conversion', () {
      // Test various stock types
      expect(PriceUtils.safePriceToString(10, defaultValue: '0'), '10');
      expect(PriceUtils.safePriceToString('5', defaultValue: '0'), '5');
      expect(PriceUtils.safePriceToString(null, defaultValue: '0'), '0');
      expect(PriceUtils.safePriceToString('', defaultValue: '0'), '0');
      expect(PriceUtils.safePriceToString('unlimited', defaultValue: '0'), 'unlimited');
    });

    test('should handle edge cases that caused original TypeError', () {
      // These are the specific cases that caused the original error
      
      // Case 1: int value where string expected
      final intValue = 123;
      expect(PriceUtils.safePriceToString(intValue), '123');
      
      // Case 2: double value where string expected  
      final doubleValue = 123.45;
      expect(PriceUtils.safePriceToString(doubleValue), '123.45');
      
      // Case 3: null value where string expected
      final nullValue = null;
      expect(PriceUtils.safePriceToString(nullValue), '0');
      
      // Case 4: empty string
      final emptyString = '';
      expect(PriceUtils.safePriceToString(emptyString), '0');
      
      // Case 5: Mixed types in a map (simulating database response)
      final mockDatabaseItem = {
        'price': 123,        // int
        'stocks': 5,         // int  
        'foodCode': 'ABC123', // string
        'name': 'Test Item', // string
      };
      
      // Verify safe conversion works for all fields
      expect(PriceUtils.safePriceToString(mockDatabaseItem['price']), '123');
      expect(PriceUtils.safePriceToString(mockDatabaseItem['stocks'], defaultValue: '0'), '5');
      expect(PriceUtils.safePriceToString(mockDatabaseItem['foodCode'], defaultValue: 'N/A'), 'ABC123');
    });

    test('should handle MenuItem parameter mapping', () {
      // Simulate the exact scenario from restaurant_screen.dart
      final mockItem = {
        'imagePath': 'https://example.com/image.jpg',
        'name': 'Test Food Item',
        'foodCode': 123,     // This was causing the error - int instead of string
        'price': 99.99,      // This was causing the error - double instead of string
        'stocks': 10,        // This was causing the error - int instead of string
      };

      // Test the exact conversions used in the fix
      final imagePath = mockItem['imagePath'] ?? '';
      final text = mockItem['name'] ?? '';
      final code = PriceUtils.safePriceToString(mockItem['foodCode'], defaultValue: 'N/A');
      final price = PriceUtils.safePriceToString(mockItem['price']);
      final stocks = PriceUtils.safePriceToString(mockItem['stocks'], defaultValue: '0');

      expect(imagePath, 'https://example.com/image.jpg');
      expect(text, 'Test Food Item');
      expect(code, '123');
      expect(price, '99.99');
      expect(stocks, '10');

      // Verify all are strings (no type errors)
      expect(imagePath, isA<String>());
      expect(text, isA<String>());
      expect(code, isA<String>());
      expect(price, isA<String>());
      expect(stocks, isA<String>());
    });
  });
}