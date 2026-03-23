// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/screens/plan_selection_screen.dart';

// Project imports:
import '../constants/constants.dart';

class CustomSnackBar {
  final BuildContext context;
  CustomSnackBar(this.context);

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> build(
    String snackMsg,
  ) {
    if (snackMsg.isNotEmpty) {
      return ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MyText(
            text: snackMsg,
            color: Colors.white,
          ),
          backgroundColor: appColor,
          dismissDirection: DismissDirection.horizontal,
          duration: const Duration(milliseconds: 1500),
          elevation: 1,
          padding: const EdgeInsets.fromLTRB(30, 15, 10, 15),
          margin: const EdgeInsets.fromLTRB(20, 15, 20, 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MyText(
          text: snackMsg,
          color: Colors.white,
        ),
        backgroundColor: trans,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(milliseconds: 1500),
        elevation: 0,
        padding: const EdgeInsets.fromLTRB(30, 15, 10, 15),
        margin: const EdgeInsets.fromLTRB(20, 15, 20, 30),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
