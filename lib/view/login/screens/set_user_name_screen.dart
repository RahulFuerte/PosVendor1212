// Dart imports:
import 'dart:developer';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

// Project imports:
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class SetNameScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationID;
  const SetNameScreen(
      {required this.phoneNumber, required this.verificationID, super.key});

  @override
  State<SetNameScreen> createState() => _SetNameScreenState();
}

class _SetNameScreenState extends State<SetNameScreen> {
  FocusNode nameFocusNode = FocusNode();
  FocusNode emailFocusNode = FocusNode();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  bool isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    nameFocusNode = FocusNode();
    emailFocusNode = FocusNode();
  }

  @override
  void dispose() {
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    super.dispose();
  }

  void checkTextFieldLength(String value) {
    setState(() {
      isButtonEnabled =
          nameController.text.length > 2 && validateEmail(emailController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          backgroundColor: appbar1,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: appbar1,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: const Text(
            "ACCOUNT DETAILS",
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          automaticallyImplyLeading: false,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 11.0),
              child: Icon(
                Icons.help_outline_rounded,
                color: Colors.white,
                size: 31,
              ),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: appbar1.withOpacity(0.4),
                    border: Border.all(color: appbar1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: double.infinity,
                  child: Center(
                    child: Lottie.asset('assets/profile.json',
                        fit: BoxFit.cover, repeat: true),
                  ),
                ),
              const Text(
                "We need some more details before we can get you started",
                style: TextStyle(
                    color: black, fontSize: 17, fontWeight: FontWeight.w500),
              ),
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          spreadRadius: 1,
                          blurRadius: 1)
                    ]),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: TextField(
                    controller: nameController,
                    onTap: () => _requestFocus(nameFocusNode),
                    focusNode: nameFocusNode,
                    cursorColor: black,
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                        labelText: "Full Name",
                        labelStyle: TextStyle(
                            color:
                                nameFocusNode.hasFocus ? black : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        border: InputBorder.none),
                    onChanged: (value) {
                      checkTextFieldLength(value);
                    },
                  ),
                ),
              ),
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          spreadRadius: 1,
                          blurRadius: 1)
                    ]),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: TextField(
                    controller: emailController,
                    onTap: () => _requestFocus(emailFocusNode),
                    focusNode: emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    obscureText: false,
                    cursorColor: black,
                    decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(
                            color: emailFocusNode.hasFocus
                                ? black
                                : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        border: InputBorder.none),
                    onChanged: (value) =>
                        checkTextFieldLength(emailController.text),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => isButtonEnabled ? UploadeUserdata() : null,
                child: Container(
                  height: h * 0.06,
                  decoration: BoxDecoration(
                      color: isButtonEnabled
                          ? appbar1
                          : Colors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                      child: Text(
                    "SAVE ACCOUNT DETAILS",
                    style: TextStyle(
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  )),
                ),
              ),
            ],
          ),
        ));
  }

  void _requestFocus(FocusNode myFocus) {
    setState(() {
      FocusScope.of(context).requestFocus(myFocus);
    });
  }

  bool validateEmail(String email) {
    // Regular expression pattern for a simple email validation
    final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Future<void> saveName(String phoneNumber, String name) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(phoneNumber, name);
  // }

  void UploadeUserdata() async {
    try {
      final phoneNumber = widget.phoneNumber;
      final userName = nameController.text;
      final uId = widget.phoneNumber;
      final String email = emailController.text;

      final userProfileCollection =
          FirebaseFirestore.instance.collection("AllUsers");

      final userData = <String, dynamic>{
        'phone': phoneNumber,
        'name': userName,
        'uID': uId,
        'email': email,
        'createdAt': DateTime.now().toString(),
      };

      await userProfileCollection.doc(uId).set(userData).then((_) {
        log("Data Uploaded successfull!");
      }).catchError((error) {
        log('Error uploading data: $error');
      });
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => Navigation(uId: phoneNumber),
          ),
          (route) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
      } else if (e.code == 'email-already-in-use') {}
    } catch (e) {
      print(e);
    }
  }
} 
//  
