import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/subscription_plan_model.dart';
import 'package:pos/view/home/screens/subscription_history_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/data/services/subscription_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  // Local Plans List State
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoadingPlans = false;

  // Local User Subscription State
  String _currentStatus = 'inactive';
  String _currentPlanType = 'free';
  // ignore: unused_field
  String? _currentPlanId;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
    _fetchPlans();
  }

  Future<void> _loadCurrentSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentStatus = prefs.getString('subscriptionStatus') ?? 'inactive';
        _currentPlanType = prefs.getString('subscriptionPlanType') ?? 'free';
        _currentPlanId = prefs.getString('subscriptionPlanId');
        final endDateStr = prefs.getString('subscriptionEndDate');
        _expiryDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
      });
    }
  }

  Future<void> _fetchPlans() async {
    if (!mounted) return;
    setState(() => _isLoadingPlans = true);
    try {
      final fetchedPlans = await _subscriptionService.getPlans();
      if (mounted) {
        setState(() {
          _plans = fetchedPlans;
          _isLoadingPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPlans = false);
        SnackBarUtils.showError(context, 'Failed to fetch plans: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPlans && _plans.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: MyText(text: AppLocale.subscriptionPlansTitle.getString(context),
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SubscriptionHistoryScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.1), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPlans,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildCurrentStatus(),
              const SizedBox(height: 24),
              _buildPlansList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: MyText(text: AppLocale.pricingPlans.getString(context),
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          MyText(text: AppLocale.growYourBusiness.getString(context),
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: primaryColor,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          MyText(text: AppLocale.pricingSubtitle.getString(context),
            fontSize: 14,
            color: const Color(0xFF64748B),
            textAlign: TextAlign.center,
            height: 1.5,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatus() {
    bool isExpired = _expiryDate != null && _expiryDate!.isBefore(DateTime.now());
    bool isActive = (_currentStatus == 'active' || _currentStatus == 'trialing') && !isExpired;
    bool isTrial = _currentStatus == 'trialing';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isActive ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: isActive ? 'You are currently on ${_currentPlanType.toUpperCase()}' : 'Membership Inactive',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                if (isActive && _expiryDate != null)
                  MyText(
                    text: '${AppLocale.expiresOnPrefix.getString(context)}${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                if (!isActive)
                  MyText(text: AppLocale.selectPlanPrompt.getString(context),
                    fontSize: 12,
                    maxLines: 2,
                    color: const Color(0xFF64748B),
                  ),
              ],
            ),
          ),
          if (isTrial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MyText(text: AppLocale.trial.getString(context), color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildPlansList() {
    return Column(
      children: _plans.map((plan) {
        bool isCurrent = _currentPlanType.toLowerCase() == (plan.name).toLowerCase();
        bool isPopular = plan.isRecommended;
        return _buildModernPlanCard(plan, isCurrent, isPopular);
      }).toList(),
    );
  }

  Widget _buildModernPlanCard(SubscriptionPlanModel plan, bool isCurrent, bool isPopular) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular ? primaryColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 0,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: MyText(text: AppLocale.mostPopular.getString(context),
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPopular ? primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        plan.price == 0 ? Icons.lightbulb_outline : (isPopular ? Icons.rocket_launch : Icons.business),
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: plan.name,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          MyText(
                            text: '${plan.durationInDays}${AppLocale.daysAccess.getString(context)}',
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MyText(
                      text: '₹${plan.price.toStringAsFixed(0)}',
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                    MyText(
                      text: ' / ${plan.pricing?.billingCycle ?? 'period'}',
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ...(plan.displayFeatures != null && plan.displayFeatures!.isNotEmpty)
                    ? plan.displayFeatures!.take(5).map((f) => _buildFeatureItem(f.title, highlight: f.highlight))
                    : (plan.legacyFeatures ?? []).take(5).map((f) => _buildFeatureItem(f)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isCurrent ? null : () => _handleSubscription(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: MyText(
                      text: isCurrent ? 'Current Plan' : 'Choose ${plan.name}',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCurrent ? Colors.grey : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: highlight ? Colors.amber : primaryColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: MyText(
              text: feature,
              fontSize: 14,
              color: highlight ? Colors.black87 : const Color(0xFF475569),
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubscription(SubscriptionPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: MyText(text: '${AppLocale.activatePlan.getString(context)}${plan.name}', fontWeight: FontWeight.bold),
        content: MyText(
          text: '${AppLocale.areYouSureUpgrade.getString(context)}${plan.name}${AppLocale.planFor.getString(context)}${plan.price.toStringAsFixed(0)}?',
          color: const Color(0xFF64748B),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: MyText(text: AppLocale.maybeLater.getString(context), color: const Color(0xFF64748B)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: MyText(text: AppLocale.yesUpgrade.getString(context), color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      _showLoading();
      try {
        await _subscriptionService.purchaseSubscription(plan.id ?? '');
        final details = await _subscriptionService.getMySubscription();

        if (details != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('subscriptionStatus', details.status ?? 'active');
          await prefs.setString('subscriptionPlanType', details.planType ?? 'free');
          if (details.planId != null) {
            await prefs.setString('subscriptionPlanId', details.planId!);
          }
          if (details.endDate != null) {
            await prefs.setString('subscriptionEndDate', details.endDate!.toIso8601String());
          }

          if (mounted) {
            setState(() {
              _currentStatus = details.status ?? 'active';
              _currentPlanType = details.planType ?? 'free';
              _currentPlanId = details.planId;
              _expiryDate = details.endDate;
            });
            Navigator.pop(context); // Close loading
            _showSuccess();
          }
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        SnackBarUtils.showError(context, 'Subscription failed: $e');
      }
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: const CircularProgressIndicator(color: primaryColor),
        ),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.stars_rounded, color: primaryColor, size: 64),
            const SizedBox(height: 24),
            MyText(text: AppLocale.subscriptionActive.getString(context), fontSize: 22, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            MyText(text: AppLocale.subscriptionActiveMsg.getString(context),
              textAlign: TextAlign.center,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: MyText(text: AppLocale.great.getString(context), color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
