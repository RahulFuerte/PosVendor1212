// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/screens/login.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/appbar.dart';
import 'package:pos/view/tab_screen/view-model/frontend/appname.dart';
import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';

import 'package:pos/view/login/screens/role_selection_screen.dart';
import '../../Super Admin/super_admin_dashboard.dart';
import '../../home/navigation.dart';
import 'new_admin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  static const keyLogin = 'isLoggedIn';

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () async {
      await checkRoleAndNavigate(context);
    });
  }

  Future<void> checkRoleAndNavigate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLogged = prefs.getBool('isLogged') ?? false;
    final String role = prefs.getString('role') ?? '';
    final String phone = prefs.getString('myPhone') ?? '';

    if (isLogged && phone.isNotEmpty) {
      Widget nextScreen;
      if (role == 'superAdmin') {
        nextScreen = const SuperAdminDashboard();
      } else {
        nextScreen = Navigation(uId: phone);
      }
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    } else {
      // Not logged in — go to Login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Login()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Screen s = Screen(context);
    return Scaffold(
      backgroundColor: white,
      appBar: const ZeroAppBar(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          appName(),
          Lottie.asset(
            "$lottiePath/splashScreenAnimation.json",
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
            width: Screen(context).width * 0.9,
            frameRate: FrameRate(90),
          ),
          SizedBox(height: 80 * s.customWidth),
          Column(
            children: [
              Image.asset("$imagesPath/bbblogo.png", height: 50),
              const MyText(
                text: "Streamlining Success, One Bill at a Time.",
                textAlign: TextAlign.center,
                color: black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
