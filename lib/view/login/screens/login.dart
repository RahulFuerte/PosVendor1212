import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/screens/admin_sign_up.dart';
import 'package:pos/view/login/screens/customer_sign_up.dart';
import 'package:pos/view/login/screens/otp.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';

class Login extends StatefulWidget {
  final String role;

  const Login({super.key, required this.role});

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
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          SnackBarUtils.showError(context, e.message ?? "Verification failed. Try again.");
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Otp(
                phoneNumber: phone,
                verificationId: verificationId,
                role: widget.role,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
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
    final bool isAdmin = widget.role == 'admin';
    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Container(
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
                      MyText(
                        text: isAdmin ? "Organization Login" : "Customer Login",
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 8),
                      MyText(
                        text: "Enter your mobile number to receive an 6-digit OTP code.",
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
                          prefixIcon: Icon(Icons.phone_android_rounded, color: primaryColor, size: 22),
                          suffixIcon:
                              _phoneController.text.length == 10 ? Icon(Icons.check_circle, color: primaryColor) : null,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
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
                                builder: (_) => isAdmin ? const AdminSignUp() : const CustomerSignUp(),
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
                                  text: isAdmin ? "Register Shop" : "Join Now",
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
