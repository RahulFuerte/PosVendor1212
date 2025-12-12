import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';
import 'package:shimmer/shimmer.dart';

class LoadingImage extends StatelessWidget {
  const LoadingImage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: theme,
        ),
        Center(
          child: Image.asset(
            'assets/icons/themeLauncherIcon.png',
            width: 200,
          ),
        ),
      ],
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      body: Shimmer.fromColors(
        baseColor: trans,
        highlightColor: theme.withOpacity(0.5).withAlpha(255),
        child: SizedBox.expand(
          child: Center(
            child: Image.asset("$iconsPath/icon.png"),
          ),
        ),
      ),
    );
  }
}

class LoadingComponent extends StatefulWidget {
  final double radius;
  final int? durationInMilliseconds;
  final Color? componentColor;
  final String? componentLocation;
  final bool? showSubComponent, showRotatingSubComponent;

  const LoadingComponent({
    Key? key,
    this.componentLocation,
    this.durationInMilliseconds,
    required this.radius,
    this.componentColor,
    this.showSubComponent,
    this.showRotatingSubComponent,
  }) : super(key: key);

  @override
  LoadingComponentState createState() => LoadingComponentState();
}

class LoadingComponentState extends State<LoadingComponent>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;

  @override
  void initState() {
    animationController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.durationInMilliseconds ?? 2500,
      ),
    )..repeat();
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // double width = widget.radius * 1.2;
    Size size = MediaQuery.of(context).size;
    double customWidth = size.width / realmeWidth;
    return Stack(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: animationController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    widget.showRotatingSubComponent == true &&
                            widget.showSubComponent == false
                        ? Image.network(
                            "https://firebasestorage.googleapis.com/v0/b/fuerte-theme.appspot.com/o/Assets%2FImages%2FthemeCartoonLeft.png?alt=media&token=59cfedef-1608-4d10-bedc-1c232e3d84ed",
                            width: 40 * customWidth,
                            height: 40 * customWidth,
                          )
                        : Container(),
                    Image.asset(
                      widget.componentLocation ?? 'assets/icons/fpLogo.png',
                      width: widget.radius,
                      height: widget.radius,
                      color: widget.componentColor ?? white,
                    ),
                  ],
                ),
              ),
              widget.showSubComponent == true
                  ? Image.network(
                      "https://firebasestorage.googleapis.com/v0/b/fuerte-theme.appspot.com/o/Assets%2FImages%2FthemeCartoonLeft.png?alt=media&token=59cfedef-1608-4d10-bedc-1c232e3d84ed",
                      width: 40 * customWidth,
                      height: 40 * customWidth,
                    )
                  // Image.asset(
                  //     'assets/images/themeCartoonLeft.png',
                  //     width: 40 * customWidth,
                  //     height: 40 * customWidth,
                  //   )
                  : Container()
            ],
          ),
        ),
      ],
    );
  }
}

class CPI extends StatelessWidget {
  final double size;
  final Color? color;
  const CPI(this.size, {this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Screen(context).infinity,
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(color: color ?? theme),
      ),
    );
  }
}

class RotatingLogo extends StatefulWidget {
  final double radius;
  final Color? color;
  const RotatingLogo(this.radius, {super.key, this.color});

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  double radius = 50;
  @override
  void initState() {
    radius = widget.radius;
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius,
      height: radius,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: animationController.value * 2 * math.pi,
            child: child,
          );
        },
        child: Image.asset(
          'assets/icons/fpLogo.png',
          width: radius * 0.9,
          height: radius * 0.9,
          color: widget.color ?? white,
        ),
      ),
    );
  }
}
