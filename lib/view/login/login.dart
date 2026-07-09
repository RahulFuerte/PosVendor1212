import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/view/login/admin_sign_up.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    final phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    if (phone.length != 10) {
      SnackBarUtils.showWarning(context, AppLocale.enterValid10DigitPhone.getString(context));
      return;
    }
    if (phone == '9999999999' && password.isEmpty) {
      password = '12345678';
    }
    if (password.isEmpty) {
      SnackBarUtils.showWarning(context, AppLocale.enterYourPasswordMsg.getString(context));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await UserService.loginWithPassword(
        phoneNumber: phone,
        password: password,
      );

      setState(() => _isLoading = false);

      if (response['success'] == true) {
        await UserService.saveUserData(
          token: response['token'],
          user: Map<String, dynamic>.from(response['user']),
        );

        // Guarantee myPhone is set — saveUserData reads it from the server response
        // which can be null/empty if the DB field is missing. Override with the
        // exact phone the user typed so the splash-screen check always passes.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('myPhone', phone);
        await prefs.setString('phoneNumber', phone);

        if (mounted) {
          final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
          await subProvider.loadSavedSubscription();
          subProvider.syncSubscriptionWithApi();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => Navigation(uId: phone)),
            (route) => false,
          );
        }
      } else {
        SnackBarUtils.showError(context, response['message'] ?? AppLocale.loginFailed.getString(context));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, e.toString());
    }
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
                      InkWell(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('clickedTryDemo', true);
                          await prefs.setBool('is_first_time_tutorial', true);
                          await prefs.setBool('is_first_time_main_tutorial', true);
                          await prefs.setBool('is_first_time_drawer_tutorial', true);
                          await prefs.setBool('is_first_time_detailed_tutorial', true);
                          await prefs.setBool('has_visited_demo', true);

                          _phoneController.text = '9999999999';
                          _passwordController.text = '12345678';
                          _loginWithPassword();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              MyText(
                                text: AppLocale.tryDemo.getString(context),
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
                // Positioned(
                //   top: 8,
                //   left: 8,
                //   child: IconButton(
                //     onPressed: () => Navigator.pop(context),
                //     icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                //   ),
                // ),
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
                        text: AppLocale.merchantLogin.getString(context),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 8),
                      MyText(
                        text: AppLocale.enterMobile.getString(context),
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 40),

                      // ─── Phone Number ─────────────────────────────────────
                      _label(AppLocale.mobileNumber.getString(context)),
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
                          hintText: AppLocale.enterYourMobile.getString(context),
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

                      const SizedBox(height: 20),

                      // ─── Password ──────────────────────────────────────────
                      _label(AppLocale.password.getString(context)),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                            letterSpacing: 2.0, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                        decoration: InputDecoration(
                          hintText: AppLocale.enterYourPassword.getString(context),
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
                          prefixIcon: const Icon(Icons.lock_rounded, color: primaryColor, size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
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

                      const SizedBox(height: 30),

                      // ─── Login Button ──────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _loginWithPassword,
                          child: _isLoading
                              ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(color: Colors.white))
                              : MyText(
                                  text: AppLocale.continueToLogin.getString(context),
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
                                TextSpan(
                                  text: AppLocale.newHereRegister.getString(context),
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "Outfit",
                                  ),
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
