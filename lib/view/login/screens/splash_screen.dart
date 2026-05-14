// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:provider/provider.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:pos/view/customer/customer_dashboard.dart';
import 'package:pos/view/login/screens/auth_landing_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/login/screens/onboard_screen.dart';
import '../../home/navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {
          _displayValue = _animation.value;
        });
      });

    _startSequence();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSequence() async {
    // Start prep logic
    final prep = _prepareData();

    // Start progress animation to ~90%
    _controller.animateTo(0.9, duration: const Duration(milliseconds: 2000));

    // Wait for data and at least some time
    await Future.wait([
      prep,
      Future.delayed(const Duration(milliseconds: 2000)),
    ]);

    // Finish animation to 100%
    await _controller.animateTo(1.0, duration: const Duration(milliseconds: 500));

    if (mounted) await _navigate();
  }

  Future<void> _prepareData() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isLogged') ?? false;

    if (mounted) {
      if (isLogged) {
        await context.read<SubscriptionProvider>().syncSubscriptionWithApi();
      } else {
        await context.read<SubscriptionProvider>().loadSavedSubscription();
      }
    }
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isLogged') ?? false;
    final role = prefs.getString('role') ?? '';
    final phone = prefs.getString('myPhone') ?? '';

    if (!mounted) return;

    if (isLogged && phone.isNotEmpty) {
      final next = role == 'customer' ? const CustomerDashboard() : Navigation(uId: phone);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Image.asset(
                            'assets/images/myBillLogo.png',
                            fit: BoxFit.contain,
                            width: 130,
                            height: 130,
                          ),
                        ),
                      ),
                    ),
                    const MyText(
                      text: 'Billing Sphere',
                      isMainHeading: true,
                      color: primaryColor,
                      fontSize: 36,
                    ),
                    const SizedBox(height: 12),
                    const MyText(
                      text: 'Billing made simple.',
                      textAlign: TextAlign.center,
                      color: Color(0xFF757575),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    const SizedBox(height: 70),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _displayValue,
                              color: primaryColor,
                              backgroundColor: const Color(0xFFF0F0F0),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MyText(
                            text: '${(_displayValue * 100).toInt()}%',
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Partners Section - Static
              Container(
                padding: const EdgeInsets.all(35),
                child: Column(
                  children: [
                    MyText(
                      text: 'OUR PARTNERS',
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: _PartnerLogo(path: '$imagesPath/razorpay.png')),
                        Container(
                          height: 35,
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(horizontal: 25),
                          color: Colors.grey.shade300,
                        ),
                        Expanded(child: _PartnerLogo(path: '$imagesPath/richpos.png')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerLogo extends StatelessWidget {
  final String path;
  const _PartnerLogo({required this.path});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(path, height: 55, fit: BoxFit.contain),
      );
}
