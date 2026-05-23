import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/view/login/splash_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';

class TourProvider extends ChangeNotifier {
  bool _isTourActive = false;
  int _currentStep = 1;
  bool _hasCompletedTour = false;

  bool get isTourActive => _isTourActive;
  int get currentStep => _currentStep;
  bool get hasCompletedTour => _hasCompletedTour;

  TourProvider() {
    _loadTourState();
  }

  Future<void> _loadTourState() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedTour = prefs.getBool('has_completed_tour_guide') ?? false;
    notifyListeners();
  }

  Future<void> startTour(BuildContext context) async {
    _isTourActive = true;
    _currentStep = 1;
    notifyListeners();

    // Navigate to splash screen to simulate first launch/onboarding experience
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> completeTour() async {
    _isTourActive = false;
    _currentStep = 1;
    _hasCompletedTour = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_tour_guide', true);
    notifyListeners();
  }

  void stopTour() {
    _isTourActive = false;
    _currentStep = 1;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 24) {
      _currentStep++;
      notifyListeners();
    } else {
      completeTour();
    }
  }

  void prevStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  void setStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  Widget buildTourTooltip({
    required BuildContext context,
    required int step,
    required String title,
    required String description,
    VoidCallback? onNext,
    VoidCallback? onPrev,
    VoidCallback? onSkip,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Premium Slate Dark Mode
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.5)),
                ),
                child: Text(
                  '${AppLocale.stepLabel.getString(context)} $step ${AppLocale.ofLabel.getString(context)} 24',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              if (onSkip != null)
                GestureDetector(
                  onTap: onSkip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocale.skipLabel.getString(context),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              fontFamily: 'Outfit',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (step > 1 && onPrev != null)
                TextButton(
                  onPressed: onPrev,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    AppLocale.prevLabel.getString(context),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (onNext != null)
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    step == 24 ? AppLocale.finishLabel.getString(context) : AppLocale.nextLabel.getString(context),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
