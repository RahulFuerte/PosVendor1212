import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class MyTextStyle {
  TextStyle get heading => const TextStyle(
        color: black,
        letterSpacing: 2,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      );

  TextStyle get description => const TextStyle(
        color: black,
        letterSpacing: 1,
        fontSize: 16,
      );
  TextStyle get buttonText => const TextStyle(
        color: black,
        letterSpacing: 1,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  TextStyle get content => const TextStyle(
        color: black,
        letterSpacing: 0.5,
        fontSize: 16,
      );
  TextStyle get contentHeading => const TextStyle(
        color: black,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        fontSize: 16,
      );
  TextStyle get transparent => const TextStyle(
        color: trans,
      );
}
