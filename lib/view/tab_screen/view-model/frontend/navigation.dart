import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Navigation {
  //PRIMARILY USED BECAUSE A POST DEVELOPMENT APPLICATION REQUIRES ROUTING ON BOTH PLATFORMS THAT ARE BEST OPTIMISED FOR SAME>
  final BuildContext context;
  Navigation(this.context);

  push(Widget child) {
    if (Platform.isIOS) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (builder) => child),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (builder) => child),
      );
    }
  }

  pushReplacement(Widget child) {
    if (Platform.isIOS) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (builder) => child),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (builder) => child),
      );
    }
  }

  pushAndRemoveUntil(Widget child) {
    if (Platform.isIOS) {
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (builder) => child),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (builder) => child),
        (route) => false,
      );
    }
  }
}
