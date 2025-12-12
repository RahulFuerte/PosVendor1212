import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

Row appName() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircleAvatar(
        backgroundColor: black,
        radius: 7,
      ),
      const SizedBox(width: 1),
      Text(
        "Invoice Pos",
        style: GoogleFonts.alfaSlabOne(
          textStyle: const TextStyle(
              fontSize: 35, fontWeight: FontWeight.w500, color: black),
        ),
      ),
      const SizedBox(width: 1),
      const CircleAvatar(
        backgroundColor: black,
        radius: 7,
      ),
    ],
  );
}
