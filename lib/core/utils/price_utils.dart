// Dart imports:
import 'dart:developer' as developer;

/// Utility class for handling price conversions safely
class PriceUtils {
  /// Safely converts a dynamic value to an integer price
  /// Handles various input types: int, double, String
  static int safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    
    try {
      if (value is int) {
        return value;
      } else if (value is double) {
        return value.round();
      } else if (value is String) {
        if (value.isEmpty) return defaultValue;
        
        // Try parsing as int first
        final intValue = int.tryParse(value);
        if (intValue != null) return intValue;
        
        // If that fails, try parsing as double and round
        final doubleValue = double.tryParse(value);
        if (doubleValue != null) return doubleValue.round();
        
        return defaultValue;
      } else {
        // Try converting to string first, then parse
        return safeParseInt(value.toString(), defaultValue: defaultValue);
      }
    } catch (e) {
      developer.log('Error parsing price value "$value": $e', name: 'PriceUtils');
      return defaultValue;
    }
  }

  /// Safely converts a dynamic value to a double price
  /// Handles various input types: int, double, String
  static double safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    
    try {
      if (value is double) {
        return value;
      } else if (value is int) {
        return value.toDouble();
      } else if (value is String) {
        if (value.isEmpty) return defaultValue;
        
        final doubleValue = double.tryParse(value);
        return doubleValue ?? defaultValue;
      } else {
        // Try converting to string first, then parse
        return safeParseDouble(value.toString(), defaultValue: defaultValue);
      }
    } catch (e) {
      developer.log('Error parsing price value "$value": $e', name: 'PriceUtils');
      return defaultValue;
    }
  }

  /// Safely converts a dynamic value to a string price
  /// Ensures consistent string representation with max 2 decimal places
  static String safePriceToString(dynamic value, {String defaultValue = '0'}) {
    if (value == null) return defaultValue;
    
    try {
      if (value is String) {
        if (value.isEmpty) return defaultValue;
        // Parse and format to ensure consistent decimal places
        final parsed = double.tryParse(value);
        if (parsed != null) {
          // Format with max 2 decimal places, remove trailing zeros
          return _formatPrice(parsed);
        }
        return value;
      } else if (value is num) {
        return _formatPrice(value.toDouble());
      } else {
        return value.toString();
      }
    } catch (e) {
      developer.log('Error converting price to string "$value": $e', name: 'PriceUtils');
      return defaultValue;
    }
  }

  /// Helper to format price with max 2 decimal places
  static String _formatPrice(double value) {
    // Round to 2 decimal places
    final rounded = (value * 100).round() / 100;
    
    // If it's a whole number, return without decimals
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    
    // Otherwise return with up to 2 decimal places
    return rounded.toStringAsFixed(2);
  }

  /// Formats a price for display with currency symbol
  static String formatPrice(dynamic value, {String currency = '₹', int decimals = 0}) {
    final price = safeParseDouble(value);
    
    if (decimals == 0) {
      return '$currency${price.round()}';
    } else {
      return '$currency${price.toStringAsFixed(decimals)}';
    }
  }

  /// Validates if a price value is valid (non-negative number)
  static bool isValidPrice(dynamic value) {
    if (value == null) return false;
    
    try {
      // First check if it's a valid number format
      if (value is String && value.isEmpty) return false;
      if (value is String) {
        // Check if string contains only valid number characters
        if (!RegExp(r'^-?\d*\.?\d+$').hasMatch(value.trim())) return false;
      }
      
      final price = safeParseDouble(value);
      return price >= 0;
    } catch (e) {
      return false;
    }
  }

  /// Calculates total from a list of items with price and quantity
  static double calculateTotal(List<Map<String, dynamic>> items) {
    double total = 0.0;
    
    for (final item in items) {
      try {
        final price = safeParseDouble(item['price']);
        final quantity = safeParseInt(item['quantity'], defaultValue: 1);
        total += price * quantity;
      } catch (e) {
        developer.log('Error calculating total for item: $item, error: $e', name: 'PriceUtils');
      }
    }
    
    return total;
  }

  /// Safely adds two price values
  static double addPrices(dynamic price1, dynamic price2) {
    return safeParseDouble(price1) + safeParseDouble(price2);
  }

  /// Safely subtracts two price values
  static double subtractPrices(dynamic price1, dynamic price2) {
    return safeParseDouble(price1) - safeParseDouble(price2);
  }

  /// Safely multiplies price by quantity
  static double multiplyPrice(dynamic price, dynamic quantity) {
    return safeParseDouble(price) * safeParseDouble(quantity);
  }

  /// Safely converts a dynamic value to a string
  /// Handles null values and ensures non-empty strings
  static String safeStringConversion(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    
    try {
      final stringValue = value.toString().trim();
      return stringValue.isEmpty ? defaultValue : stringValue;
    } catch (e) {
      developer.log('Error converting to string "$value": $e', name: 'PriceUtils');
      return defaultValue;
    }
  }

  /// Safely converts a dynamic value to an integer price (alias for safeParseInt)
  /// This method is specifically for price conversion with better error handling
  static int safePriceConversion(dynamic value, {int defaultValue = 0}) {
    return safeParseInt(value, defaultValue: defaultValue);
  }
}
