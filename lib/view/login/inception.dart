import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/view/tab_screen/view-model/backend/auth/phone_authentication.dart';
import 'package:pos/view/tab_screen/view-model/backend/permission.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/constants/strings.dart';
import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';
import 'package:pos/view/tab_screen/view-model/frontend/snack_bar.dart';
import 'package:pos/view/tab_screen/view-model/frontend/textformfields.dart';
import 'package:pos/view/tab_screen/view-model/widgets/inception_component/inception_component.dart';
import 'package:pos/view/login/otp.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../tab_screen/view-model/backend/provider/login_provider.dart';
import '../tab_screen/view-model/frontend/appbar.dart';
import '../tab_screen/view-model/frontend/navigation.dart';

class Inception extends StatefulWidget {
  const Inception({super.key});

  @override
  State<Inception> createState() => _InceptionState();
}

class _InceptionState extends State<Inception> {
  TextEditingController phone = TextEditingController(),
      otp = TextEditingController();
  late Navigation nav;
  Permissions permissions = Permissions();

  @override
  void initState() {
    nav = Navigation(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Screen s = Screen(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: white,
      appBar: ZeroAppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          // statusBarColor: theme,
          statusBarColor: const Color.fromARGB(255, 5, 93, 8).withOpacity(0.6),
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Stack(
        children: [
          Shape(s),
          SizedBox.expand(
            child: Padding(
              padding: EdgeInsets.all(40 * s.customWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BeOnTimeAnimatedText(),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 30 * s.customWidth),
                    child: phoneField(s),
                  ),
                  Consumer<LoginProvider>(
                    builder: (context, value, _) => CustomButton(
                      label: "Send OTP",
                      isLoading: value.isProcessing,
                      onTap: () async {
                        if (phone.text.length == 10) {
                          if (!(await permissions.checkSms())) {
                            await permissions.requestSms();
                          }
                          value.setPhone = "+91${phone.text}";
                          if (mounted) {
                            String result = await PhoneAuthentication(
                              context: context,
                              mounted: mounted,
                              lp: value,
                            ).sendPhoneOtp();
                            if (mounted) {
                              CustomSnackBar(context).build(result);
                            }
                          }
                          Future.delayed(
                            const Duration(milliseconds: 1000),
                            () => nav.push(const OTP()),
                          );
                        } else {
                          CustomSnackBar(context).build(
                            "Incomplete phone number.",
                          );
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 25 * s.customWidth,
                      bottom: 30 * s.customWidth,
                    ),
                    child: termsAndConditions(s),
                  ),
                  // or(s),
                  // SocialIcon(
                  //   "assets/icons/googleLogo.png",
                  //   onTap: () async {
                  //     String response = await GoogleAuthentication(
                  //       context,
                  //       mounted,
                  //     ).signInViaGoogle();
                  //     if (response.isNotEmpty && mounted) {
                  //       CustomSnackBar(context).build(response);
                  //     }
                  //   },
                  // ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Row or(Screen s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Divider(
            endIndent: 20 * s.customWidth,
            indent: 20 * s.customWidth,
          ),
        ),
        Text(
          'OR',
          style: TextStyle(
            color: theme,
            fontWeight: FontWeight.w900,
            fontSize: 16 * s.customWidth,
          ),
        ),
        Expanded(
          child: Divider(
            indent: 20 * s.customWidth,
            endIndent: 20 * s.customWidth,
          ),
        ),
      ],
    );
  }

  Padding termsAndConditions(Screen s) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 30 * s.customWidth,
        vertical: 15 * s.customWidth,
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(height: 1.5),
          children: [
            TextSpan(
              text: "By continuing, you agree to the ",
              style: TextStyle(
                color: grey,
                fontSize: 13 * s.customWidth,
              ),
            ),
            TextSpan(
              text: "Terms & Conditions ",
              style: TextStyle(
                // color: theme,
                color: black,
                fontSize: 13 * s.customWidth,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrlString(
                      AppStrings.themePrivacyPolicy,
                    ),
            ),
            TextSpan(
              text: "and ",
              style: TextStyle(
                color: grey,
                fontSize: 13 * s.customWidth,
              ),
            ),
            TextSpan(
              text: "Privacy Policy ",
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrlString(
                      AppStrings.themePrivacyPolicy,
                    ),
              style: TextStyle(
                // color: theme,
                color: black,
                fontSize: 13 * s.customWidth,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(
              text: "of Invoice Pro.",
              style: TextStyle(
                color: grey,
                fontSize: 13 * s.customWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  CustomTextFormField phoneField(Screen s) {
    return CustomTextFormField(
      controller: phone,
      hintText: "Enter your mobile number",
      prefixIcon: PrefixIcon91(s),
      autoFillHints: const [
        AutofillHints.telephoneNumberNational,
      ],
      inputFormatters: [
        LengthLimitingTextInputFormatter(10),
        FilteringTextInputFormatter.digitsOnly,
      ],
      keyboardType: TextInputType.number,
    );
  }
}
