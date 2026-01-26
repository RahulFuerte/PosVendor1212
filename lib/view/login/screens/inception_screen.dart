// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/login/screens/sign_up_screen.dart';
import 'package:pos/view/tab_screen/view-model/frontend/snack_bar.dart';

// Package imports:
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/core/utils/permission.dart';
import 'package:pos/data/datasources/remote/phone_authentication.dart';
import 'package:pos/view/login/providers/login_provider.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  bool isOtpSent = false;

  Permissions permissions = Permissions();

  /// 🔹 SEND OTP
  Future<void> sendOtp(LoginProvider lp) async {
    if (lp.isProcessing) return;

    if (phoneController.text.length != 10) {
      CustomSnackBar(context).build("Incomplete phone number.");
      return;
    }

    lp.startProcessing();

    try {
      if (!(await permissions.checkSms())) {
        await permissions.requestSms();
      }

      lp.setPhone = "+91${phoneController.text}";

      await PhoneAuthentication(
        context: context,
        mounted: mounted,
        lp: lp,
      ).sendPhoneOtp();

      if (!mounted) return;

      setState(() {
        isOtpSent = true;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar(context).build("Failed to send OTP");
      }
    } finally {
      lp.endProcessing();
    }
  }

  Future<void> verifyOtp() async {
    final lp = context.read<LoginProvider>();

    final otp = otpController.text.trim();

    if (otp.length != 6) {
      CustomSnackBar(context).build("Enter valid OTP");
      return;
    }

    for (int i = 0; i < 6; i++) {
      lp.controllers[i].text = otp[i];
    }

    lp.startProcessing();

    String result = await PhoneAuthentication(
      context: context,
      mounted: mounted,
      lp: lp,
    ).verifyPhoneOTP();

    if (!mounted) return;

    lp.endProcessing();
    CustomSnackBar(context).build(result);
  }

  void changeNumber() {
    final lp = context.read<LoginProvider>();

    setState(() {
      isOtpSent = false;
      phoneController.clear();
      otpController.clear();
    });

    lp.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 15),

          /// 🔥 LOGO
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Image.asset(
                "assets/images/myBillLogo.jpeg",
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),

          /// ⬜ LOGIN CARD
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Login using your phone number",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    /// 📞 PHONE
                    _label("Phone Number"),
                    _inputField(
                      controller: phoneController,
                      hint: "Enter phone number",
                      icon: Icons.phone,
                      enabled: !isOtpSent,
                    ),

                    /// ✏️ CHANGE NUMBER
                    if (isOtpSent)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: changeNumber,
                          child: const Text(
                            "Change number",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    /// 🔢 OTP
                    if (isOtpSent) ...[
                      const SizedBox(height: 30),
                      _label("Enter OTP"),
                      Pinput(
                        length: 6,
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        defaultPinTheme: PinTheme(
                          width: 52,
                          height: 56,
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                        focusedPinTheme: PinTheme(
                          width: 52,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appbar1, width: 2),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    Consumer<LoginProvider>(
                      builder: (context, lp, _) {
                        return SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appbar1,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: lp.isProcessing
                                ? null
                                : isOtpSent
                                    ? verifyOtp
                                    : () => sendOtp(lp),
                            child: lp.isProcessing
                                ? Transform.scale(
                                    scale: 0.6,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    isOtpSent ? "VERIFY OTP" : "SEND OTP",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUp()),
                        ),
                        child: const Text(
                          "Don’t have an account? Sign Up",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 LABEL
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  /// 🔹 INPUT FIELD
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [
        LengthLimitingTextInputFormatter(10),
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(letterSpacing: 2, fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        prefixIcon: Icon(icon, color: appbar1),
        suffixIcon: controller.text.length == 10 ? Icon(Icons.check_circle, color: appbar1) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}


// Old Login Code Below

// class Inception extends StatefulWidget {
//   const Inception({super.key});

//   @override
//   State<Inception> createState() => _InceptionState();
// }

// class _InceptionState extends State<Inception> {
//   TextEditingController phone = TextEditingController(), otp = TextEditingController();
//   late Navigation nav;
//   Permissions permissions = Permissions();

//   @override
//   void initState() {
//     nav = Navigation(context);
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Screen s = Screen(context);
//     return Scaffold(
//       resizeToAvoidBottomInset: false,
//       backgroundColor: white,
//       appBar: ZeroAppBar(
//         systemOverlayStyle: SystemUiOverlayStyle(
//           // statusBarColor: theme,
//           statusBarIconBrightness: Brightness.dark,
//         ),
//       ),
//       body: Stack(
//         children: [
//           Shape(s),
//           SizedBox.expand(
//             child: Padding(
//               padding: EdgeInsets.all(40 * s.customWidth),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const BeOnTimeAnimatedText(),
//                   Padding(
//                     padding: EdgeInsets.symmetric(vertical: 30 * s.customWidth),
//                     child: phoneField(s),
//                   ),
//                   Consumer<LoginProvider>(
//                     builder: (context, value, _) => CustomButton(
//                       label: "Send OTP",
//                       isLoading: value.isProcessing,
//                       onTap: () async {
//                         if (phone.text.length == 10) {
//                           if (!(await permissions.checkSms())) {
//                             await permissions.requestSms();
//                           }
//                           value.setPhone = "+91${phone.text}";
//                           if (mounted) {
//                             String result = await PhoneAuthentication(
//                               context: context,
//                               mounted: mounted,
//                               lp: value,
//                             ).sendPhoneOtp();
//                             if (mounted) {
//                               CustomSnackBar(context).build(result);
//                             }
//                           }
//                           Future.delayed(
//                             const Duration(milliseconds: 1000),
//                             () => nav.push(const OTP()),
//                           );
//                         } else {
//                           CustomSnackBar(context).build(
//                             "Incomplete phone number.",
//                           );
//                         }
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: EdgeInsets.only(
//                       top: 25 * s.customWidth,
//                       bottom: 30 * s.customWidth,
//                     ),
//                     child: termsAndConditions(s),
//                   ),
//                   // or(s),
//                   // SocialIcon(
//                   //   "assets/icons/googleLogo.png",
//                   //   onTap: () async {
//                   //     String response = await GoogleAuthentication(
//                   //       context,
//                   //       mounted,
//                   //     ).signInViaGoogle();
//                   //     if (response.isNotEmpty && mounted) {
//                   //       CustomSnackBar(context).build(response);
//                   //     }
//                   //   },
//                   // ),
//                 ],
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   Row or(Screen s) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Expanded(
//           child: Divider(
//             endIndent: 20 * s.customWidth,
//             indent: 20 * s.customWidth,
//           ),
//         ),
//         Text(
//           'OR',
//           style: TextStyle(
//             color: theme,
//             fontWeight: FontWeight.w900,
//             fontSize: 16 * s.customWidth,
//           ),
//         ),
//         Expanded(
//           child: Divider(
//             indent: 20 * s.customWidth,
//             endIndent: 20 * s.customWidth,
//           ),
//         ),
//       ],
//     );
//   }

//   Padding termsAndConditions(Screen s) {
//     return Padding(
//       padding: EdgeInsets.symmetric(
//         horizontal: 30 * s.customWidth,
//         vertical: 15 * s.customWidth,
//       ),
//       child: RichText(
//         text: TextSpan(
//           style: const TextStyle(height: 1.5),
//           children: [
//             TextSpan(
//               text: "By continuing, you agree to the ",
//               style: TextStyle(
//                 color: grey,
//                 fontSize: 13 * s.customWidth,
//               ),
//             ),
//             TextSpan(
//               text: "Terms & Conditions ",
//               style: TextStyle(
//                 // color: theme,
//                 color: black,
//                 fontSize: 13 * s.customWidth,
//                 fontWeight: FontWeight.w500,
//                 decoration: TextDecoration.underline,
//               ),
//               recognizer: TapGestureRecognizer()
//                 ..onTap = () => launchUrlString(
//                       AppStrings.themePrivacyPolicy,
//                     ),
//             ),
//             TextSpan(
//               text: "and ",
//               style: TextStyle(
//                 color: grey,
//                 fontSize: 13 * s.customWidth,
//               ),
//             ),
//             TextSpan(
//               text: "Privacy Policy ",
//               recognizer: TapGestureRecognizer()
//                 ..onTap = () => launchUrlString(
//                       AppStrings.themePrivacyPolicy,
//                     ),
//               style: TextStyle(
//                 // color: theme,
//                 color: black,
//                 fontSize: 13 * s.customWidth,
//                 fontWeight: FontWeight.w500,
//                 decoration: TextDecoration.underline,
//               ),
//             ),
//             TextSpan(
//               text: "of Invoice Pro.",
//               style: TextStyle(
//                 color: grey,
//                 fontSize: 13 * s.customWidth,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   CustomTextFormField phoneField(Screen s) {
//     return CustomTextFormField(
//       controller: phone,
//       hintText: "Enter your mobile number",
//       prefixIcon: PrefixIcon91(s),
//       autoFillHints: const [
//         AutofillHints.telephoneNumberNational,
//       ],
//       inputFormatters: [
//         LengthLimitingTextInputFormatter(10),
//         FilteringTextInputFormatter.digitsOnly,
//       ],
//       keyboardType: TextInputType.number,
//     );
//   }
// }
