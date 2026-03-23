// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

void showSnackBar(BuildContext context, String content) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: MyText(
        text: content,
        color: Colors.white,
      ),
      backgroundColor: primaryColor,
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ),
  );
}
