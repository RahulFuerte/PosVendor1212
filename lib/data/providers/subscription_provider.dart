import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos/data/models/subscription_plan_model.dart';
import 'package:pos/data/models/subscription_history_model.dart';
import 'package:pos/data/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionProvider extends ChangeNotifier {
  DateTime? _expiryDate;
  Duration? _remaining;
  Timer? _timer;
  bool _initialized = false;

  String _status = 'inactive';
  String _planType = 'free';
  String? _planId;

  List<SubscriptionPlanModel> _plans = [];
  bool _isLoadingPlans = false;

  List<SubscriptionHistoryModel> _history = [];
  bool _isLoadingHistory = false;

  Duration? get remaining => _remaining;
  bool get isInitialized => _initialized;
  bool get isExpired => _initialized && _remaining != null && _remaining! <= Duration.zero;
  String get status => _status;
  String get planType => _planType;
  String? get planId => _planId;

  SubscriptionPlanModel? get activePlanData {
    if (_plans.isEmpty) return null;
    try {
      if (_planId != null) {
        return _plans.firstWhere((p) => p.id == _planId);
      }
      return _plans.firstWhere((p) => p.name.toLowerCase() == _planType.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  bool hasPermission(String featureKey,
      {bool checkCreate = false, bool checkView = false, bool checkEdit = false, bool checkDelete = false}) {
    final activePlan = activePlanData;
    if (activePlan == null) return false;

    // Check new nested features structure
    if (activePlan.features != null) {
      PlanFeature? feature;
      try {
        feature = activePlan.features!.firstWhere((f) => f.key == featureKey);
      } catch (_) {
        feature = null;
      }

      if (feature == null || !feature.enabled) return false;

      bool allowed = true;
      if (feature.permissions != null) {
        if (checkCreate && !feature.permissions!.create) allowed = false;
        if (checkView && !feature.permissions!.view) allowed = false;
        if (checkEdit && !feature.permissions!.edit) allowed = false;
        if (checkDelete && !feature.permissions!.delete) allowed = false;
      }
      return allowed;
    }

    return true;
  }

  int getLimit(String limitKey, {int defaultValue = -1}) {
    final activePlan = activePlanData;
    if (activePlan == null || activePlan.limits == null) return defaultValue;

    PlanLimit? limit;
    try {
      limit = activePlan.limits!.firstWhere((l) => l.key == limitKey);
    } catch (_) {
      // Use default if limit not found
    }
    return limit != null ? limit.value : defaultValue;
  }

  List<SubscriptionPlanModel> get plans => _plans;
  bool get isLoadingPlans => _isLoadingPlans;

  List<SubscriptionHistoryModel> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;

  final SubscriptionService _subscriptionService = SubscriptionService();

  void setExpiry(DateTime? expiry, {String status = 'active', String planType = 'free', String? planId}) {
    // Check if anything actually changed
    bool changed =
        _expiryDate != expiry || _status != status || _planType != planType || _planId != planId || !_initialized;

    if (!changed && _initialized) return;

    _status = status;
    _planType = planType;
    _planId = planId;
    _expiryDate = expiry;
    _initialized = true;

    if (expiry == null) {
      _remaining = null;
      _timer?.cancel();
    } else {
      _startTimer();
    }

    notifyListeners();
  }

  Future<void> loadSavedSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = prefs.getString('subscriptionStatus') ?? 'inactive';
      final planType = prefs.getString('subscriptionPlanType') ?? 'free';
      final planId = prefs.getString('subscriptionPlanId');
      final endDateStr = prefs.getString('subscriptionEndDate');

      DateTime? endDate;
      if (endDateStr != null) {
        endDate = DateTime.tryParse(endDateStr);
      }

      // Fetch specific plan data if we have an ID
      if (planId != null && _plans.isEmpty) {
        try {
          final plan = await _subscriptionService.getPlanById(planId);
          _plans = [plan];
        } catch (e) {
          debugPrint('Error fetching plan by ID in loadSavedSubscription: $e');
          // Fallback if needed
          await fetchPlans();
        }
      }

      // Set expiry and initialize (this will notify listeners)
      setExpiry(endDate, status: status, planType: planType, planId: planId);
    } catch (e) {
      debugPrint('Error loading saved subscription: $e');
    }
  }

  Future<void> syncSubscriptionWithApi() async {
    try {
      final details = await _subscriptionService.getMySubscription();
      if (details != null) {
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('subscriptionStatus', details.status ?? 'active');
        await prefs.setString('subscriptionPlanType', details.planType ?? 'free');
        if (details.planId != null) {
          await prefs.setString('subscriptionPlanId', details.planId!);
        }
        if (details.endDate != null) {
          await prefs.setString('subscriptionEndDate', details.endDate!.toIso8601String());
        }

        // Fetch plan data to ensure features/limits are fresh
        if (details.planId != null) {
          try {
            final plan = await _subscriptionService.getPlanById(details.planId!);
            _plans = [plan];
          } catch (e) {
            debugPrint('Error fetching plan by ID during sync: $e');
            await fetchPlans();
          }
        }

        // Update state
        setExpiry(details.endDate,
            status: details.status ?? 'active', planType: details.planType ?? 'free', planId: details.planId);
      }
    } catch (e) {
      debugPrint('Error syncing subscription with API: $e');
      // Fallback to saved data if API fails or is offline
      await loadSavedSubscription();
    }
  }

  Future<void> fetchPlans() async {
    if (_isLoadingPlans || _plans.isNotEmpty) return;
    _isLoadingPlans = true;
    notifyListeners();
    try {
      _plans = await _subscriptionService.getPlans();
    } catch (e) {
      debugPrint('Error fetching plans: $e');
    } finally {
      _isLoadingPlans = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _history = await _subscriptionService.getSubscriptionHistory();
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<bool> subscribe(String planId) async {
    try {
      // Use the new purchase endpoint which supports extensions
      await _subscriptionService.purchaseSubscription(planId);

      // Re-fetch my subscription info to get fresh data
      final details = await _subscriptionService.getMySubscription();
      if (details != null) {
        // Fetch plan details to ensure features/limits are updated
        if (details.planId != null) {
          try {
            final plan = await _subscriptionService.getPlanById(details.planId!);
            _plans = [plan];
          } catch (e) {
            debugPrint('Error fetching plan by ID after subscribe: $e');
          }
        }

        setExpiry(details.endDate,
            status: details.status ?? 'active', planType: details.planType ?? 'free', planId: details.planId);

        // Persist to SharedPreferences so other components (like Drawer) see it
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('subscriptionStatus', details.status ?? 'active');
        await prefs.setString('subscriptionPlanType', details.planType ?? 'free');
        if (details.planId != null) {
          await prefs.setString('subscriptionPlanId', details.planId!);
        }
        if (details.endDate != null) {
          await prefs.setString('subscriptionEndDate', details.endDate!.toIso8601String());
        }

        // Final notification to ensure all listeners are updated
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error subscribing: $e');
      rethrow; // Rethrow to handle in UI
    }
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

  void reset() {
    _timer?.cancel();
    _expiryDate = null;
    _remaining = null;
    _initialized = false;
    _status = 'inactive';
    _planType = 'free';
    _planId = null;
    _plans = [];
    _history = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
