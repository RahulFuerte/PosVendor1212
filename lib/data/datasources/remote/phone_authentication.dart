// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/view/login/screens/new_admin_screen.dart';
import 'package:pos/view/login/screens/role_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Project imports:
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/frontend/snack_bar.dart';
import '../../../view/login/providers/login_provider.dart';
import '../../../view/Super Admin/super_admin_dashboard.dart';

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
  // final Backend _backend = Backend();
  // bool _isLoading = false;
  String adminUid = '';
  Future<String> sendPhoneOtp({bool skipDocCheck = false}) async {
    String result = "";
    lp.startProcessing();

    // if (!skipDocCheck) {
    //   try {
    //     final result = await FirebaseFunctions.instance
    //         .httpsCallable('checkUserExists')
    //         .call({
    //       'phone': lp.phone,
    //     });

    //     if (result.data['exists'] == false) {
    //       lp.endProcessing();
    //       return "You are not a member, please register or signup.";
    //     }
    //   } catch (e) {
    //     lp.endProcessing();
    //     return "Error checking user: ${e.toString()}";
    //   }
    // }

    await _fa.verifyPhoneNumber(
      timeout: const Duration(seconds: 120),
      phoneNumber: lp.phone,
      verificationCompleted: (PhoneAuthCredential phoneAuthCredential) async {
        lp.startProcessing();
        lp.setSmsCode = phoneAuthCredential.smsCode!;
        Future.delayed(
          const Duration(milliseconds: 250),
          () async => result = await _afterSendingOtp(phoneAuthCredential),
        );
        lp.endProcessing();
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.message!.contains("Network")) {
          result = "Please check your internet connection.";
        } else if (e.code.contains("too-many-requests")) {
          result =
              "You've made too many requests, please try again after some time.";
        } else if (e.code.contains("invalid-phone-number")) {
          result = "Invalid phone number.";
        } else {
          result = "Something went wrong, please try later.";
        }
      },
      codeSent: (verificationID, [int? forceResendingToken]) {
        lp.setVerificationID = verificationID;
        if (mounted) {
          CustomSnackBar(context).build("OTP sent successfully.");
        }
      },
      codeAutoRetrievalTimeout: (verificationId) async {},
    );
    lp.endProcessing();
    return result;
  }

  Future<String> verifyPhoneOTP() async {
    String code = "";
    for (TextEditingController controller in lp.controllers) {
      code += controller.text;
    }
    lp.setSmsCodeManually = code;
    if (lp.smsCode.length == 6) {
      String result = await _afterSendingOtp(PhoneAuthProvider.credential(
        verificationId: lp.verificationID,
        smsCode: lp.smsCode,
      ));

      if (result == "Login successful.") {
        // User successfully logged in, set the bool value to true

        await _setUserLoggedIn();
      }

      return result;
    } else {
      return "Incorrect OTP entered.";
    }
  }

  Future<User?> verifyOtpOnly() async {
    String code = "";
    for (TextEditingController controller in lp.controllers) {
      code += controller.text;
    }
    lp.setSmsCodeManually = code;
    if (lp.smsCode.length == 6) {
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
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential);
      User? user = userCredential.user;

      if (user != null) {
        try {
          // Optimize: Check Custom Claims for Role
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
            // Default User
            nextScreen = Navigation(uId: lp.phone);
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => nextScreen,
            ),
            (route) => false,
          );
        } catch (e) {
          result = "Something went wrong fetching user data!";
          debugPrint(e.toString());
        }
      }
    } catch (e) {
//this account is invalid
      if (e.hashCode == 130296352) {
        result = "Account already exists.";
      } else {
        result = "Something went wrong.";
        debugPrint("Error: ${e.toString()}");
      }
    }

    lp.endProcessing();
    return result;
  }

// Function to set the user's login status to true in SharedPreferences
  Future<void> _setUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('myPhone', lp.phone);
    await prefs.setBool('isLogged', true);
  }
}
