import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OfflineTTS {
  // android\app\src\main\kotlin\com\fuertedevelopers\pos\MainActivity.kt
  // These Method Channel Code Has Been Assign Above Kotline File For Spake The Final Amount Price ⬇️⬇️⬇️⬇️⬇️  Writtern By Brij Parekh

  static const MethodChannel _channel = MethodChannel('com.fuertedevelopers.pos/tts');

  static Future<void> speak(String text) async {
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } catch (e) {
      // silent fail (do not crash POS)
      debugPrint('TTS error: $e');
    }
  }
}

String numberToWords(int number) {
  if (number == 0) return "zero";

  final units = [
    "",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen"
  ];

  final tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];

  String convert(int n) {
    if (n < 20) return units[n];

    if (n < 100) {
      return tens[n ~/ 10] + (n % 10 != 0 ? " ${units[n % 10]}" : "");
    }

    if (n < 1000) {
      return "${units[n ~/ 100]} hundred"
          "${n % 100 != 0 ? " ${convert(n % 100)}" : ""}";
    }

    if (n < 100000) {
      return "${convert(n ~/ 1000)} thousand"
          "${n % 1000 != 0 ? " ${convert(n % 1000)}" : ""}";
    }

    if (n < 10000000) {
      return "${convert(n ~/ 100000)} lakh"
          "${n % 100000 != 0 ? " ${convert(n % 100000)}" : ""}";
    }

    return "${convert(n ~/ 10000000)} crore"
        "${n % 10000000 != 0 ? " ${convert(n % 10000000)}" : ""}";
  }

  return convert(number);
}
