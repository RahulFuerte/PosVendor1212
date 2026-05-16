import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/admin_sign_up.dart';
import 'package:pos/view/login/otp.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/view/home/navigation.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyPhone() async {
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      SnackBarUtils.showWarning(context, "Enter a valid 10-digit phone number.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // This callback will be called in two situations:
          // 1. On Android devices that support self-verification (Instant verification)
          // 2. On some devices where the SMS code is automatically retrieved
          setState(() => _isLoading = false);
          try {
            // Sign in automatically
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            final firebaseToken = await userCredential.user!.getIdToken();

            if (firebaseToken != null && mounted) {
              // Navigate to OTP screen or handle login directly
              // For simplicity and consistency with existing logic, we can still go to OTP
              // but we might want to auto-submit there.
              // Alternatively, handle login here if we have everything.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Otp(
                    phoneNumber: phone,
                    verificationId: "", // Empty because it's already verified
                    credential: credential, // Pass the credential for auto-login
                  ),
                ),
              );
            }
          } catch (e) {
            SnackBarUtils.showError(context, "Auto-verification failed: ${e.toString()}");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          debugPrint("Firebase Verification Failed: ${e.code} - ${e.message}");

          String errorMessage = "Verification failed. Try again.";
          if (e.code == 'invalid-phone-number') {
            errorMessage = "The provided phone number is not valid.";
          } else if (e.code == 'quota-exceeded') {
            errorMessage = "SMS quota exceeded. Please try again later.";
          } else if (e.code == 'too-many-requests') {
            errorMessage = "Too many attempts. Please try again later.";
          } else if (e.code == 'app-not-authorized') {
            errorMessage = "App not authorized. Check SHA-1/SHA-256 in Firebase console.";
          }

          SnackBarUtils.showError(context, e.message ?? errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Otp(
                phoneNumber: phone,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error in verifyPhone: $e");
      SnackBarUtils.showError(context, "Error: ${e.toString()}");
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 260,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Image.asset(
                          'assets/images/myBillLogo.png',
                          fit: BoxFit.contain,
                          width: 130,
                          height: 130,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // TRY DEMO BUTTON
                      InkWell(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final bool hasVisitedDemo = prefs.getBool('has_visited_demo') ?? false;
                          if (!hasVisitedDemo) {
                            await prefs.setBool('is_first_time_tutorial', true);
                            await prefs.setBool('is_first_time_main_tutorial', true);
                            await prefs.setBool('is_first_time_drawer_tutorial', true);
                            await prefs.setBool('is_first_time_detailed_tutorial', true);
                            await prefs.setBool('has_visited_demo', true);
                          }
                          await prefs.setBool('isDemoMode', true);
                          await prefs.setBool('isLogged', true);
                          await prefs.setString('role', 'admin');
                          await prefs.setString('adminUid', 'demo_admin_123');
                          await prefs.setString('_id', 'demo_admin_123');
                          await prefs.setString('myPhone', '9999999999');
                          await prefs.setString('shopName', 'Billing Spher');
                          await prefs.setString('address', 'MG Road, Bangalore');
                          await prefs.setString('contact', '9999999999');
                          await prefs.setString('upiId', 'merchant@upi');

                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Navigation(uId: 'demo_admin_123'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              MyText(
                                text: 'Try Demo',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            // ─── LOGIN CARD ──────────────────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: "Merchant Login",
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 8),
                      MyText(
                        text: "Enter your mobile number to receive a 6-digit OTP code.",
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 40),

                      // ─── Phone Number ─────────────────────────────────────
                      _label("Mobile Number"),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            letterSpacing: 3.2, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "Enter Your Mobile Number",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: primaryColor, size: 22),
                          suffixIcon: _phoneController.text.length == 10
                              ? const Icon(Icons.check_circle, color: primaryColor)
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: primaryColor, width: 1.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ─── Get OTP Button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _verifyPhone,
                          child: _isLoading
                              ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(color: Colors.white))
                              : const MyText(
                                  text: "CONTINUE TO VERIFY",
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 16,
                                ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminSignUp(),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black54, fontSize: 14),
                              children: [
                                const TextSpan(
                                    text: "New here? ", style: TextStyle(color: Colors.grey, fontFamily: "Outfit")),
                                TextSpan(
                                  text: "Register Shop",
                                  style:
                                      TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: "Outfit"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MyText(text: text, fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
      );
}
