// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:pos/core/utils/price_utils.dart';

void main() {
  group('PriceUtils Tests', () {
    group('safeParseInt', () {
      test('should parse valid integer strings', () {
        expect(PriceUtils.safeParseInt('123'), 123);
        expect(PriceUtils.safeParseInt('0'), 0);
        expect(PriceUtils.safeParseInt('999'), 999);
      });

      test('should parse valid integers', () {
        expect(PriceUtils.safeParseInt(123), 123);
        expect(PriceUtils.safeParseInt(0), 0);
        expect(PriceUtils.safeParseInt(-5), -5);
      });

      test('should parse and round doubles', () {
        expect(PriceUtils.safeParseInt(123.7), 124);
        expect(PriceUtils.safeParseInt(123.2), 123);
        expect(PriceUtils.safeParseInt('123.9'), 124);
      });

      test('should handle invalid inputs with default value', () {
        expect(PriceUtils.safeParseInt('abc'), 0);
        expect(PriceUtils.safeParseInt(''), 0);
        expect(PriceUtils.safeParseInt(null), 0);
        expect(PriceUtils.safeParseInt('abc', defaultValue: 100), 100);
      });

      test('should handle decimal strings that caused the original error', () {
        expect(PriceUtils.safeParseInt('0.0'), 0);
        expect(PriceUtils.safeParseInt('123.0'), 123);
        expect(PriceUtils.safeParseInt('99.99'), 100);
      });
    });

    group('safeParseDouble', () {
      test('should parse valid double strings', () {
        expect(PriceUtils.safeParseDouble('123.45'), 123.45);
        expect(PriceUtils.safeParseDouble('0.0'), 0.0);
        expect(PriceUtils.safeParseDouble('999.99'), 999.99);
      });

      test('should parse integers as doubles', () {
        expect(PriceUtils.safeParseDouble(123), 123.0);
        expect(PriceUtils.safeParseDouble('123'), 123.0);
      });

      test('should handle invalid inputs with default value', () {
        expect(PriceUtils.safeParseDouble('abc'), 0.0);
        expect(PriceUtils.safeParseDouble(''), 0.0);
        expect(PriceUtils.safeParseDouble(null), 0.0);
        expect(PriceUtils.safeParseDouble('abc', defaultValue: 10.5), 10.5);
      });
    });

    group('safePriceToString', () {
      test('should convert various types to string', () {
        expect(PriceUtils.safePriceToString(123), '123');
        expect(PriceUtils.safePriceToString(123.45), '123.45');
        expect(PriceUtils.safePriceToString('123'), '123');
      });

      test('should handle null and empty values', () {
        expect(PriceUtils.safePriceToString(null), '0');
        expect(PriceUtils.safePriceToString(''), '0');
        expect(PriceUtils.safePriceToString(null, defaultValue: '100'), '100');
      });
    });

    group('formatPrice', () {
      test('should format prices with currency symbol', () {
        expect(PriceUtils.formatPrice(123), '₹123');
        expect(PriceUtils.formatPrice(123.45), '₹123.45');
        expect(PriceUtils.formatPrice('99.99'), '₹99.99');
      });

      test('should format with decimals when specified', () {
        expect(PriceUtils.formatPrice(123.45, decimals: 2), '₹123.45');
        expect(PriceUtils.formatPrice(123.40, decimals: 2), '₹123.4');
      });

      test('should use custom currency symbol', () {
        expect(PriceUtils.formatPrice(123, currency: '\$'), '\$123');
      });
    });

    group('calculateTotal', () {
      test('should calculate total from item list', () {
        final items = [
          {'price': '10', 'quantity': 2},
          {'price': 15, 'quantity': '3'},
          {'price': 20.5, 'quantity': 1},
        ];
        expect(PriceUtils.calculateTotal(items), 85.5);
      });

      test('should handle missing or invalid values', () {
        final items = [
          {'price': '10', 'quantity': 2},
          {'price': 'invalid', 'quantity': 3}, // Invalid price
          {'name': 'item'}, // Missing price and quantity
        ];
        expect(PriceUtils.calculateTotal(items), 20.0);
      });
    });

    group('isValidPrice', () {
      test('should validate positive prices', () {
        expect(PriceUtils.isValidPrice(123), true);
        expect(PriceUtils.isValidPrice('123.45'), true);
        expect(PriceUtils.isValidPrice(0), true);
      });

      test('should reject negative prices', () {
        expect(PriceUtils.isValidPrice(-10), false);
        expect(PriceUtils.isValidPrice('-5.5'), false);
      });

      test('should reject invalid values', () {
        expect(PriceUtils.isValidPrice('abc'), false);
        expect(PriceUtils.isValidPrice(null), false);
      });
    });

    group('arithmetic operations', () {
      test('should safely add prices', () {
        expect(PriceUtils.addPrices(10, 20), 30.0);
        expect(PriceUtils.addPrices('10.5', '20.5'), 31.0);
        expect(PriceUtils.addPrices('invalid', 20), 20.0);
      });

      test('should safely subtract prices', () {
        expect(PriceUtils.subtractPrices(30, 10), 20.0);
        expect(PriceUtils.subtractPrices('30.5', '10.5'), 20.0);
      });

      test('should safely multiply price by quantity', () {
        expect(PriceUtils.multiplyPrice(10, 3), 30.0);
        expect(PriceUtils.multiplyPrice('10.5', '2'), 21.0);
      });
    });
  });
}
