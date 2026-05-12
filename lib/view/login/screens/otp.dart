import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:pos/data/models/user_model.dart';

import 'package:pos/data/services/user_service.dart';
import 'package:pos/data/services/unknown_customer_service.dart';
import 'package:pos/view/customer/customer_dashboard.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:provider/provider.dart';

class Otp extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final String role;
  final PhoneAuthCredential? credential;

  const Otp({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    required this.role,
    this.credential,
  });

  @override
  State<Otp> createState() => _OtpState();
}

class _OtpState extends State<Otp> {
  final TextEditingController otpController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  bool _isLoading = false;
  bool _isResending = false;

  late String _verificationId;
  int _resendTimer = 55;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startTimer();
    
    // If we received a credential (auto-verification), sign in immediately
    if (widget.credential != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loginWithCredential(widget.credential!);
      });
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 55);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        timer.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  Future<void> _resendOTP() async {
    if (_resendTimer != 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${widget.phoneNumber}',
        forceResendingToken: widget.resendToken, // Use the token to force resend
        verificationCompleted: (PhoneAuthCredential credential) {
          _loginWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isResending = false);
          _showSnackBar(e.message ?? 'Failed to resend OTP');
        },
        codeSent: (String newVerificationId, int? resendToken) {
          setState(() {
            _verificationId = newVerificationId;
            _isResending = false;
          });
          _showSnackBar('OTP resent successfully');
          _startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isResending = false);
      _showSnackBar("Error: ${e.toString()}");
    }
  }

  Future<void> _loginWithCredential(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseToken = await userCredential.user!.getIdToken();
      
      if (firebaseToken == null) throw Exception("Failed to get Firebase token");
      
      await _handlePostLogin(firebaseToken);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.message ?? 'Login failed');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Something went wrong. Please try again.');
    }
  }

  Future<void> _handlePostLogin(String firebaseToken) async {
    if (widget.role == 'customer') {
      final response = await UnknownCustomerService().login(firebaseToken);
      setState(() => _isLoading = false);

      if (response['success'] == true) {
        await UserService.saveUserData(
          token: response['token'],
          user: Map<String, dynamic>.from(response['customer']),
        );

        if (mounted) {
          final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
          await subProvider.loadSavedSubscription();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const CustomerDashboard()),
            (route) => false,
          );
        }
      } else {
        _showSnackBar(response['message'] ?? 'Login failed');
      }
    } else {
      final response = await UserService.firebaseLogin(firebaseToken);
      setState(() => _isLoading = false);

      if (response['success'] == true) {
        await UserService.saveUserData(
          token: response['token'],
          user: Map<String, dynamic>.from(response['user']),
        );

        if (mounted) {
          final role = response['user']['role'] ?? 'staff';
          final phone = widget.phoneNumber;

          final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
          await subProvider.loadSavedSubscription();
          subProvider.syncSubscriptionWithApi();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => Navigation(uId: phone, role: role)),
            (route) => false,
          );
        }
      } else {
        _showSnackBar(response['message'] ?? 'Login failed');
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (otpController.text.length != 6) {
      _showSnackBar('Enter 6 digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpController.text.trim(),
      );

      await _loginWithCredential(credential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Invalid OTP or something went wrong.');
    }
  }

  void _showSnackBar(String message) {
    SnackBarUtils.showInfo(context, message);
  }

  String get _timerText {
    int minutes = _resendTimer ~/ 60;
    int seconds = _resendTimer % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.black,
        fontFamily: 'Outfit',
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
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
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const MyText(
                text: 'Verification Code',
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 12),
              MyText(
                text: 'We have sent the 6-digit code to',
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
              MyText(
                text: '+91 ${widget.phoneNumber}',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              const SizedBox(height: 48),

              // OTP Input
              Pinput(
                controller: otpController,
                focusNode: focusNode,
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                hapticFeedbackType: HapticFeedbackType.lightImpact,
                onCompleted: (_) => _verifyOTP(),
              ),

              const SizedBox(height: 40),

              // Resend Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MyText(
                    text: 'Resend code in ',
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  MyText(
                    text: _timerText,
                    fontWeight: FontWeight.bold,
                    color: _resendTimer > 0 ? primaryColor : Colors.red,
                    fontSize: 14,
                  ),
                ],
              ),

              const SizedBox(height: 50),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _verifyOTP,
                  child: _isLoading
                      ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(color: Colors.white))
                      : const MyText(
                          text: 'VERIFY & CONTINUE',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // Resend Link
              if (_resendTimer == 0)
                GestureDetector(
                  onTap: _isResending ? null : _resendOTP,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MyText(text: "Didn't receive the code? ", fontSize: 14),
                      _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                            )
                          : const MyText(
                              text: 'Resend Now',
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 14,
                            ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
