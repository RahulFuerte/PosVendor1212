// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Project imports:
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
      const MyText(
        text: "Invoice Pos",
        fontSize: 35,
        fontWeight: FontWeight.w500,
        color: black,
      ),
      const SizedBox(width: 1),
      const CircleAvatar(
        backgroundColor: black,
        radius: 7,
      ),
    ],
  );
}
