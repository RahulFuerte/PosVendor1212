
// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/loading.dart';
import '../../frontend/screen.dart';

class Shape extends StatelessWidget {
  const Shape(
    this.s, {
    Key? key,
  }) : super(key: key);

  final Screen s;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: InceptionClipper(s.topPadding),
      child: Container(
        // color: theme,
        // color: mainAppColor,
        // color: Colors.black,
        color: const Color.fromARGB(255, 5, 93, 8).withOpacity(0.6),
        width: s.width,
        height: s.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(20 * s.customWidth),
              child: AnimatedTextKit(
                animatedTexts: [
                  TyperAnimatedText(
                    'Sign In',
                    textStyle: TextStyle(
                      fontSize: 43 * s.customWidth,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    speed: const Duration(milliseconds: 400),
                  ),
                ],
                isRepeatingAnimation: true,
                repeatForever: true,
                pause: const Duration(seconds: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20 * s.customWidth).copyWith(
                bottom: kBottomNavigationBarHeight * s.customWidth,
              ),
              child: Text(
                "Or Sign Up!",
                style: TextStyle(
                  fontSize: 26 * s.customWidth,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SemiCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double w = size.width, h = size.height;
    final path = Path();
    path.lineTo(w, 0);
    // path.conicTo(-w * 2, h / 2, w, h, 10);
    path.conicTo(-w * 10, h / 2, w, h, 0.1);
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class InceptionClipper extends CustomClipper<Path> {
  final double topPadding;
  InceptionClipper(this.topPadding);
  @override
  Path getClip(Size size) {
    double w = size.width, h = size.height;
    final path = Path();
    path.lineTo(w, 0);
    path.lineTo(0, h * 0.175);
    path.lineTo(0, h * 0.825);
    path.lineTo(w, h - topPadding / 1.5);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class SocialIcon extends StatelessWidget {
  final String path;
  final VoidCallback onTap;
  const SocialIcon(
    this.path, {
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Screen s = Screen(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Card(
        shape: const CircleBorder(),
        elevation: 5,
        color: white,
        margin: EdgeInsets.only(
          top: 40 * s.customWidth,
          bottom: 125 * s.customWidth,
        ),
        child: Padding(
          padding: EdgeInsets.all(17.5 * s.customWidth),
          child: Image.asset(
            path,
            height: 40 * s.customWidth,
            width: 40 * s.customWidth,
          ),
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final double? borderRadius;
  final VoidCallback onTap;
  final String label;
  final IconData? icon;
  final Color? backgroundColor, foregroundColor;
  final bool isLoading;
  const CustomButton({
    Key? key,
    required this.onTap,
    required this.isLoading,
    this.borderRadius,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Screen s = Screen(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedSwitcher(
        reverseDuration: const Duration(milliseconds: 250),
        duration: const Duration(milliseconds: 250),
        child: isLoading
            ? CPI(30 * s.customWidth)
            : Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    borderRadius ?? 10 * s.customWidth,
                  ),
                ),
                margin: EdgeInsets.zero,
                // color: backgroundColor ?? theme,
                color: backgroundColor ?? const Color.fromARGB(255, 5, 93, 8).withOpacity(0.6),
                child: Container(
                  width: s.infinity,
                  padding: EdgeInsets.all(15 * s.customWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: foregroundColor ?? white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17 * s.customWidth,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(width: 20 * s.customWidth),
                      Icon(
                        icon ?? MdiIcons.send,
                        color: foregroundColor ?? white,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class BeOnTimeAnimatedText extends StatelessWidget {
  const BeOnTimeAnimatedText({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Screen s = Screen(context);
    return AnimatedTextKit(
      animatedTexts: [
        WavyAnimatedText(
          "INVOICE PRO",
          textStyle: TextStyle(
            // color: theme,
            // color: mainAppColor,
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 30 * s.customWidth,
          ),
          speed: const Duration(milliseconds: 400),
        ),
      ],
      isRepeatingAnimation: true,
      repeatForever: true,
      stopPauseOnTap: true,
    );
  }
}
