// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:lottie/lottie.dart';

// Project imports:
import 'package:pos/view/login/screens/inception_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/appbar.dart';
import 'package:pos/view/tab_screen/view-model/frontend/appname.dart';
import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';

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
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        IdTokenResult tokenResult = await user.getIdTokenResult(true);
        bool isAdmin = tokenResult.claims?['admin'] == true;
        bool isSuperAdmin = tokenResult.claims?['superAdmin'] == true;
        if (isSuperAdmin) {
          // It's a Super Admin!
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/super_admin_home');
          }
        } else if (isAdmin) {
          // It's an Admin!
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/admin_home');
          }
        } else {
          // It's a regular User/Customer
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/user_home');
          }
        }
      } catch (e) {
        debugPrint("Error checking role: $e");
        // Fallback to login if something goes wrong
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Login()),
          );
        }
      }
    } else {
      // User is not logged in, navigate to LoginScreen
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
          SizedBox(
            height: 80 * s.customWidth,
          ),
          Column(
            children: [
              Image.asset("$imagesPath/bbblogo.png", height: 50),
              const Text(
                "Streamlining Success, One Bill at a Time.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: black,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
