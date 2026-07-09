import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/view/login/language_selection_screen.dart';
import 'package:pos/view/home/screens/settings/whatsapp_templates_screen.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  bool _tourShowing = false;
  TutorialCoachMark? _tourMark;
  TourProvider? _tourProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tourProvider = context.read<TourProvider>();
      _tourProvider!.addListener(_onTourStateChanged);
      _onTourStateChanged();
    });
  }

  @override
  void dispose() {
    _tourProvider?.removeListener(_onTourStateChanged);
    _tourMark?.finish();
    super.dispose();
  }

  void _onTourStateChanged() {
    if (!mounted) return;
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    if (tourProvider.isTourActive && tourProvider.currentStep == 31 && !_tourShowing) {
      _tourShowing = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && tourProvider.isTourActive && tourProvider.currentStep == 31) {
          _showTour();
        } else {
          _tourShowing = false;
        }
      });
    }
  }

  void _showTour() {
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final targets = [
      TargetFocus(
        identify: "settings_restart_tour",
        keyTarget: TourKeys.settingsRestartTourKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 31,
                title: AppLocale.restartTourGuide.getString(context),
                description: AppLocale.tourDesc24.getString(context),
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
    ];

    final validTargets = targets.where((t) {
      final k = t.keyTarget;
      return k == null || k.currentContext != null;
    }).toList();
    if (validTargets.isEmpty) {
      _tourShowing = false;
      if (tourProvider.isTourActive) tourProvider.completeTour();
      return;
    }

    _tourMark = TutorialCoachMark(
      targets: validTargets,
      hideSkip: true,
      colorShadow: Colors.black.withValues(alpha: 0.85),
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        _tourShowing = false;
        if (tourProvider.isTourActive) {
          tourProvider.completeTour();
        }
      },
      onSkip: () {
        _tourShowing = false;
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: MyText(
            text: AppLocale.settings.getString(context),
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(AppLocale.general.getString(context)),
          // _settingTile(
          //   icon: Icons.print_outlined,
          //   title: AppLocale.printerSettings.getString(context),
          //   onTap: () {
          //     // Navigate to printer settings
          //   },
          // ),
          // _settingTile(
          //   icon: Icons.receipt,
          //   title: AppLocale.billingSettings.getString(context),
          //   onTap: () {
          //     // Navigate to notification settings
          //   },
          // ),
          _settingTile(
            icon: Icons.message,
            title: 'WhatsApp Templates',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WhatsappTemplatesScreen(),
              ),
            ),
          ),
          _settingTile(
            key: TourKeys.settingsRestartTourKey,
            icon: Icons.refresh_outlined,
            title: AppLocale.restartTourGuide.getString(context),
            onTap: () {
              final tourProvider = Provider.of<TourProvider>(context, listen: false);
              tourProvider.startTour(context);
            },
          ),
          _settingTile(
            icon: Icons.language_rounded,
            title: AppLocale.selectLanguage.getString(context),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0C6B0F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MyText(
                text: FlutterLocalization.instance.currentLocale?.languageCode.toUpperCase() ?? 'EN',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0C6B0F),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(isFirstLaunch: false),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 🔹 Section title widget
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MyText(
        text: title,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  // 🔹 Setting tile widget
  Widget _settingTile({
    Key? key,
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon, color: iconColor ?? Colors.black),
      title: MyText(
        text: title,
        color: textColor,
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
