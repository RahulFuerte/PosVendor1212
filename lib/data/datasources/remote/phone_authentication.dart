// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/view/login/screens/new_admin_screen.dart';
import 'package:pos/view/login/screens/role_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';

// Project imports:
import 'package:pos/view/home/navigation.dart';
import '../../../view/login/providers/login_provider.dart';
import '../../../view/Super Admin/super_admin_dashboard.dart';
import 'dart:async';

class PhoneAuthentication {
  final BuildContext context;
  final bool mounted;
  LoginProvider lp;
  PhoneAuthentication({
    required this.context,
    required this.mounted,
    required this.lp,
  });

  final FirebaseAuth _fa = FirebaseAuth.instance;

  Future<String> sendPhoneOtp({bool skipDocCheck = false}) async {
    lp.startProcessing();
    final String phone = lp.phone.trim();

    if (phone.isEmpty) {
      lp.endProcessing();
      return "Phone number cannot be empty.";
    }

    try {
      final String result = await _initiatePhoneVerification(phone);
      lp.endProcessing();
      return result;
    } catch (e) {
      lp.endProcessing();
      developer.log('Critical error in sendPhoneOtp: ${e.toString()}',
          name: 'PhoneAuthentication');
      return "Failed to send OTP. Please try again.";
    }
  }

  Future<String> _initiatePhoneVerification(String phone) async {
    final completer = Completer<String>();
    bool completerResolved = false;

    void resolveCompleter(String message) {
      if (!completerResolved) {
        completerResolved = true;
        completer.complete(message);
      }
    }

    try {
      await _fa.verifyPhoneNumber(
        timeout: const Duration(seconds: 120),
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential phoneAuthCredential) async {
          // This can be triggered automatically on some devices
          developer.log('Phone verification completed automatically',
              name: 'PhoneAuthentication');
          if (phoneAuthCredential.smsCode != null) {
            lp.setSmsCode = phoneAuthCredential.smsCode!;
          }
          await _afterSendingOtp(phoneAuthCredential);
          resolveCompleter("Login successful.");
        },
        verificationFailed: (FirebaseAuthException e) {
          developer.log('Phone verification failed: ${e.code} - ${e.message}',
              name: 'PhoneAuthentication');
          String errorMessage = "Something went wrong, please try later.";
          if (e.code == 'network-request-failed' ||
              (e.message?.contains("Network") ?? false)) {
            errorMessage = "Please check your internet connection.";
          } else if (e.code == "too-many-requests") {
            errorMessage = "Too many requests. Please try again later.";
          } else if (e.code == "invalid-phone-number") {
            errorMessage = "Invalid phone number.";
          } else if (e.code == "channel-error") {
            errorMessage = "Internal connection error. Please restart the app.";
          }
          resolveCompleter(errorMessage);
        },
        codeSent: (verificationID, [int? forceResendingToken]) {
          developer.log('OTP code sent. VerificationID: $verificationID',
              name: 'PhoneAuthentication');
          lp.setVerificationID = verificationID;
          resolveCompleter("OTP sent successfully.");
        },
        codeAutoRetrievalTimeout: (verificationId) {
          developer.log('Code auto-retrieval timeout',
              name: 'PhoneAuthentication');
          lp.setVerificationID = verificationId;
          // We don't necessarily want to resolve the completer here if it was already resolved by codeSent
        },
      );
    } catch (e) {
      developer.log('Error calling verifyPhoneNumber: ${e.toString()}',
          name: 'PhoneAuthentication');
      resolveCompleter("Error: ${e.toString()}");
    }

    return completer.future;
  }

  Future<String> verifyPhoneOTP() async {
    String code = "";
    for (TextEditingController controller in lp.controllers) {
      code += controller.text.trim();
    }
    lp.setSmsCodeManually = code;

    if (lp.verificationID.isEmpty) {
      return "Verification process not started. Please request OTP again.";
    }

    if (lp.smsCode.length == 6) {
      try {
        String result = await _afterSendingOtp(PhoneAuthProvider.credential(
          verificationId: lp.verificationID,
          smsCode: lp.smsCode,
        ));

        if (result == "Login successful.") {
          await _setUserLoggedIn();
        }
        return result;
      } catch (e) {
        developer.log('Error in verifyPhoneOTP: ${e.toString()}',
            name: 'PhoneAuthentication');
        return "Verification failed. Please try again.";
      }
    } else {
      return "Incorrect OTP entered.";
    }
  }

  Future<User?> verifyOtpOnly() async {
    String code = "";
    for (TextEditingController controller in lp.controllers) {
      code += controller.text.trim();
    }
    lp.setSmsCodeManually = code;

    if (lp.smsCode.length == 6 && lp.verificationID.isNotEmpty) {
      try {
        UserCredential userCredential = await _fa.signInWithCredential(
          PhoneAuthProvider.credential(
            verificationId: lp.verificationID,
            smsCode: lp.smsCode,
          ),
        );
        return userCredential.user;
      } catch (e) {
        debugPrint("OTP Verification Failed: $e");
        return null;
      }
    }
    return null;
  }

  Future<String> _afterSendingOtp(
      PhoneAuthCredential phoneAuthCredential) async {
    lp.startProcessing();
    String result = "Login successful.";

    try {
      // Consistent use of _fa
      UserCredential userCredential =
          await _fa.signInWithCredential(phoneAuthCredential);
      User? user = userCredential.user;

      if (user != null) {
        try {
          final idTokenResult = await user.getIdTokenResult(true);
          bool isAdmin = idTokenResult.claims?['admin'] == true;
          bool isSuperAdmin = idTokenResult.claims?['superAdmin'] == true;

          Widget nextScreen;
          if (lp.phone == "+919999999999") {
            nextScreen = RoleSelectionScreen(phone: lp.phone);
          } else if (isSuperAdmin) {
            nextScreen = const SuperAdminDashboard();
          } else if (isAdmin) {
            nextScreen = const NewAdminScreen();
          } else {
            nextScreen = Navigation(uId: lp.phone);
          }

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => nextScreen),
              (route) => false,
            );
          }
        } catch (e) {
          result = "Something went wrong fetching user data!";
          developer.log('Token error: ${e.toString()}',
              name: 'PhoneAuthentication');
        }
      } else {
        result = "Failed to sign in. User is null.";
      }
    } on FirebaseAuthException catch (e) {
      developer.log(
          'FirebaseAuthException in _afterSendingOtp: ${e.code} - ${e.message}',
          name: 'PhoneAuthentication');
      if (e.code == 'invalid-verification-code') {
        result = "Incorrect OTP entered.";
      } else if (e.code == 'session-expired') {
        result = "OTP session has expired. Please request a new one.";
      } else {
        result = "Authentication failed: ${e.message}";
      }
    } catch (e) {
      developer.log('General error in _afterSendingOtp: ${e.toString()}',
          name: 'PhoneAuthentication');
      result = "Something went wrong.";
    } finally {
      lp.endProcessing();
    }

    return result;
  }

// Function to set the user's login status to true in SharedPreferences
  Future<void> _setUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('myPhone', lp.phone);
    await prefs.setBool('isLogged', true);
  }
}
