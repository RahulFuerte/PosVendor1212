import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';

class TourProvider extends ChangeNotifier {
  bool _isTourActive = false;
  int _currentStep = 7;
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
    _currentStep = 7;
    notifyListeners();

    // Pop back to the root (Navigation) — user is already logged in
    Navigator.of(context).popUntil((route) => route.isFirst);
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
    _currentStep = 7;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 31) {
      _currentStep++;
      notifyListeners();
    } else {
      completeTour();
    }
  }

  void prevStep() {
    if (_currentStep > 7) {
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
    return SafeArea(
      child: Center(
        child: Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor, // Theme green
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.15)),
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
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Text(
                  '${AppLocale.stepLabel.getString(context)} ${step - 6} ${AppLocale.ofLabel.getString(context)} 25',
                  style: const TextStyle(
                    color: Colors.white,
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
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocale.skipLabel.getString(context),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
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
              color: Colors.white.withOpacity(0.9),
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
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
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    step == 31 ? AppLocale.finishLabel.getString(context) : AppLocale.nextLabel.getString(context),
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
      ),
      ),
    );
  }
}
