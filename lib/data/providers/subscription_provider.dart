import 'dart:async';
import 'package:flutter/material.dart';

class SubscriptionProvider extends ChangeNotifier {
  DateTime? _expiryDate;
  Duration? _remaining;
  Timer? _timer;
  bool _initialized = false;

  Duration? get remaining => _remaining;
  bool get isInitialized => _initialized;
  bool get isExpired => _initialized && _remaining != null && _remaining! <= Duration.zero;

  void setExpiry(DateTime expiry) {
    if (_expiryDate == expiry && _initialized) return;

    _expiryDate = expiry;
    _initialized = true;

    _startTimer();
    notifyListeners(); 
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_expiryDate == null) return;

      final diff = _expiryDate!.difference(DateTime.now());

      if (diff.isNegative) {
        _remaining = Duration.zero;
        _timer?.cancel();
      } else {
        _remaining = diff;
      }

      notifyListeners();
    });
  }

  String get formattedTime {
    if (_remaining == null) return '--:--:--:--';

    final d = _remaining!;
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return '${days.toString().padLeft(2, '0')}:'
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
