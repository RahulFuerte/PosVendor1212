// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/view/login/onboard_screen.dart';
import 'package:provider/provider.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localization/flutter_localization.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/login/language_selection_screen.dart';
import '../home/navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    final prep = _prepareData();

    await Future.wait([
      prep,
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

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
    final phone = prefs.getString('myPhone') ?? '';
    final isDemoMode = prefs.getBool('isDemoMode') ?? false;
    final isLangSelected = prefs.getBool('is_language_selected') ?? false;

    if (!mounted) return;

    if (!isLangSelected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(isFirstLaunch: true)),
      );
      return;
    }

    if (isLogged && phone.isNotEmpty) {
      if (isDemoMode) {
        await prefs.setBool('is_first_time_tutorial', true);
        await prefs.setBool('is_first_time_main_tutorial', true);
        await prefs.setBool('is_first_time_drawer_tutorial', true);
        await prefs.setBool('is_first_time_detailed_tutorial', true);
      }
      final next = Navigation(uId: phone);
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
                    MyText(
                      text: AppLocale.appTitle.getString(context),
                      isMainHeading: true,
                      color: primaryColor,
                      fontSize: 36,
                    ),
                    const SizedBox(height: 70),
                  ],
                ),
              ),

              // Partners Section - Static
              Container(
                padding: const EdgeInsets.all(35),
                child: Column(
                  children: [
                    MyText(
                      text: AppLocale.ourPartners.getString(context),
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PartnerLogo(
                          path: '$imagesPath/razorpay.png',
                        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8ECF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(
          path,
          height: 24,
          width: 100, // Explicit width constraint to make it proportional
          fit: BoxFit.contain,
        ),
      );
}
