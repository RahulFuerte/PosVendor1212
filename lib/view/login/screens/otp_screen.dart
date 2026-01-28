// // Flutter imports:
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// // Package imports:
// import 'package:lottie/lottie.dart';
// import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
// import 'package:provider/provider.dart';

// // Project imports:
// import 'package:pos/data/datasources/remote/phone_authentication.dart';
// import 'package:pos/view/login/providers/login_provider.dart';
// import 'package:pos/view/login/screens/inception_screen.dart';
// import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
// import 'package:pos/view/tab_screen/view-model/frontend/navigation.dart';
// import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';
// import 'package:pos/view/tab_screen/view-model/frontend/snack_bar.dart';
// import 'package:pos/view/tab_screen/view-model/frontend/text_styles.dart';
// import 'package:pos/view/tab_screen/view-model/widgets/inception_component/inception_component.dart';

// class OTP extends StatefulWidget {
//   const OTP({super.key});

//   @override
//   State<OTP> createState() => _OTPState();
// }

// class _OTPState extends State<OTP> {
//   late Navigation nav;

//   @override
//   void initState() {
//     nav = Navigation(context);
//     super.initState();
//   }

//   goBack() {
//     if (mounted) {
//       nav.pushAndRemoveUntil(const Login());
//       Provider.of<LoginProvider>(context, listen: false).reset();
//     }
//   }

//   MyTextStyle ts = MyTextStyle();
//   @override
//   Widget build(BuildContext context) {
//     Screen s = Screen(context);
//     return Scaffold(
//       backgroundColor: white,
//       appBar: AppBar(
//         automaticallyImplyLeading: true,
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         backgroundColor: white,
//        // iconTheme: const IconThemeData(color: black),
//         leading: IconButton(
//           onPressed: () => goBack(),
//           icon: Icon(MdiIcons.arrowLeft),
//         ),
//         systemOverlayStyle: const SystemUiOverlayStyle(
//           statusBarColor: white,
//           statusBarIconBrightness: Brightness.dark,
//         ),
//       ),
//       body: Consumer<LoginProvider>(
//         builder: (context, lp, _) => Padding(
//           padding: EdgeInsets.all(20 * s.customWidth),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Text(
//                   "Verify OTP",
//                   style: Theme.of(context)
//                       .textTheme
//                       .headlineLarge!
//                       .copyWith(color: black, fontWeight: FontWeight.bold),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.only(top: 21, bottom: 31),
//                   child: SizedBox(
//                     height: 250,
//                     width: 250,
//                     child: Center(
//                       child: Lottie.asset('assets/login.json',
//                           fit: BoxFit.cover, repeat: true),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 12 * s.customWidth),
//                 const Text(
//                     "We have sent the verification code to your mobile number",
//                     style: TextStyle(color: Colors.grey)),
//                 Padding(
//                   padding: EdgeInsets.symmetric(vertical: 10 * s.customWidth),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         lp.phone,
//                         style: Theme.of(context).textTheme.titleMedium,
//                       ),
//                       GestureDetector(
//                         onTap: () => goBack(),
//                         child: Padding(
//                           padding: EdgeInsets.only(left: 10 * s.customWidth),
//                           child: Icon(
//                             MdiIcons.pencilCircle,
//                             color: black,
//                           ),
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 10 * s.customWidth),
//                 Row(
//                   children: [
//                     otpBox(
//                       lp.controllers[0],
//                       focusNode: lp.firstFocusNode,
//                     ),
//                     otpBox(lp.controllers[1]),
//                     otpBox(lp.controllers[2]),
//                     otpBox(lp.controllers[3]),
//                     otpBox(lp.controllers[4]),
//                     otpBox(
//                       lp.controllers[5],
//                       isLast: true,
//                       focusNode: lp.lastFocusNode,
//                     ),
//                   ],
//                 ),
//                 GestureDetector(
//                   behavior: HitTestBehavior.opaque,
//                   onTap: () {
//                     for (TextEditingController controller in lp.controllers) {
//                       controller.clear();
//                     }
//                     FocusScope.of(context).unfocus();
//                     FocusScope.of(context).requestFocus(lp.firstFocusNode);
//                   },
//                   child: Container(
//                     alignment: Alignment.centerRight,
//                     padding: const EdgeInsets.all(20),
//                     child: Text(
//                       "Clear",
//                       style: Theme.of(context)
//                           .textTheme
//                           .titleSmall!
//                           .copyWith(color: black),
//                     ),
//                   ),
//                 ),
//                 CustomButton(
//                   isLoading: lp.isProcessing,
//                   label: "Verify OTP",
//                   // backgroundColor:
//                   //     const Color.fromARGB(255, 5, 93, 8).withOpacity(0.6),
//                   // borderRadius: 10,
//                   onTap: () async {
//                     String result = await PhoneAuthentication(
//                       context: context,
//                       mounted: mounted,
//                       lp: lp,
//                     ).verifyPhoneOTP();
                        
//                     if (mounted) {
//                       CustomSnackBar(context).build(result);
//                     }
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Expanded otpBox(
//     TextEditingController controller, {
//     bool? isLast,
//     FocusNode? focusNode,
//   }) {
//     Screen s = Screen(context);
//     return Expanded(
//       child: Padding(
//         padding: EdgeInsets.only(right: 12 * s.customWidth),
//         child: TextField(
//           focusNode: focusNode,
//           autofocus: true,
//           autofillHints: const [
//             AutofillHints.oneTimeCode,
//           ],
//           style: Theme.of(context).textTheme.headlineSmall,
//           controller: controller,
//           cursorColor: black,
//           onChanged: (value) {
//             if (value.isNotEmpty) {
//               controller.text = value[value.length - 1];
//               if (!(isLast ?? false)) {
//                 FocusScope.of(context).nextFocus();
//               } else {
//                 FocusScope.of(context).unfocus();
//               }
//             }
//           },
//           onTap: () {
//             controller.clear();
//           },
//           keyboardType: TextInputType.number,
//           inputFormatters: [
//             // LengthLimitingTextInputFormatter(1),
//             FilteringTextInputFormatter.digitsOnly,
//           ],
//           textAlign: TextAlign.center,
//           decoration: InputDecoration(
//             contentPadding: EdgeInsets.all(10 * s.customWidth),
//             border: border(),
//             enabledBorder: border(),
//             focusedBorder: border(color: black),
//           ),
//         ),
//       ),
//     );
//   }

//   OutlineInputBorder border({Color? color}) {
//     return OutlineInputBorder(
//       borderRadius: BorderRadius.circular(5),
//       borderSide: BorderSide(
//         color: color ?? grey,
//         width: color == null ? 1 : 2,
//       ),
//     );
//   }
// }
