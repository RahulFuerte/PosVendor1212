import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class Screen {
  late BuildContext context;
  Screen(this.context);

  MediaQueryData get mediaQuery => MediaQuery.of(context);

  Size get size => mediaQuery.size;

  double get infinity => double.infinity;
  double get width => size.width;
  double get height => size.height;
  double get customWidth => width / realmeWidth;
  double get topPadding => mediaQuery.viewPadding.top;
  double get bottomPadding => mediaQuery.viewPadding.bottom;
}
