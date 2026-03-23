import 'dart:async';
import 'package:flutter/material.dart';

class SubscriptionProvider extends ChangeNotifier {
  DateTime? _expiryDate;
  Duration? _remaining;
  Timer? _timer;
  bool _initialized = false;

  String _status = 'inactive';
  String _planType = 'free';

  Duration? get remaining => _remaining;
  bool get isInitialized => _initialized;
  bool get isExpired => _initialized && _remaining != null && _remaining! <= Duration.zero;
  String get status => _status;
  String get planType => _planType;

  void setExpiry(DateTime? expiry, {String status = 'active', String planType = 'free'}) {
    _status = status;
    _planType = planType;
    
    if (expiry == null) {
      _expiryDate = null;
      _remaining = null;
      _initialized = true;
      _timer?.cancel();
      notifyListeners();
      return;
    }

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
