import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

void showSnackBar(BuildContext context, String content) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        content,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: primaryColor,
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ),
  );
}
