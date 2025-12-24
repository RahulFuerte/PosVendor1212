import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/appbar.dart';
import 'package:pos/view/login/inception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tab_screen/view-model/frontend/appname.dart';
import '../tab_screen/view-model/frontend/screen.dart';

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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLogged = prefs.getBool('isLogged') ?? false;
      String myPhone = prefs.getString('myPhone') ?? '';

      if (isLogged && mounted) {
        // User is already logged in, navigate to HomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Navigation(
              uId: myPhone,
            ),
          ),
        );
      } else {
        // User is not logged in, navigate to LoginScreen
        mounted?Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const Inception(),
          ),
        ):null;
      }
    });
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
