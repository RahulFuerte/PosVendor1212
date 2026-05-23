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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/view/login/language_selection_screen.dart';
import 'package:pos/view/login/login.dart';
import '../home/navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  TutorialCoachMark? _tourMark;

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  @override
  void dispose() {
    _tourMark?.finish();
    super.dispose();
  }

  Future<void> _startSequence() async {
    final tourProvider = context.read<TourProvider>();
    if (tourProvider.isTourActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showTour();
        });
      });
      return;
    }

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

  void _showTour() {
    final tourProvider = context.read<TourProvider>();
    final targets = [
      TargetFocus(
        identify: "splash_logo",
        keyTarget: TourKeys.splashLogoKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 1,
                title: AppLocale.tourTitle1.getString(context),
                description: AppLocale.tourDesc1.getString(context),
                onNext: () => controller.next(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "splash_title",
        keyTarget: TourKeys.splashTitleKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 2,
                title: AppLocale.tourTitle2.getString(context),
                description: AppLocale.tourDesc2.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "splash_partner",
        keyTarget: TourKeys.splashPartnerKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 3,
                title: AppLocale.tourTitle3.getString(context),
                description: AppLocale.tourDesc3.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
    ];

    _tourMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.85),
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        if (tourProvider.isTourActive) {
          tourProvider.setStep(4);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const Login()),
          );
        }
      },
      onSkip: () {
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
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
                          key: TourKeys.splashLogoKey,
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
                      key: TourKeys.splashTitleKey,
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
                          key: TourKeys.splashPartnerKey,
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
  const _PartnerLogo({super.key, required this.path});

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
