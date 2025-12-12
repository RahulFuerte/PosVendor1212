import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/backend/shared_preferences.dart';

class Backend {
  final FirebaseFirestore ff = FirebaseFirestore.instance;
  final FirebaseAuth fa = FirebaseAuth.instance;
  final MySharedPreferences msp = MySharedPreferences();
  CollectionReference userInfo =
      FirebaseFirestore.instance.collection("1AllUsers");
  CollectionReference userBotInfo =
      FirebaseFirestore.instance.collection("1BotUsers");

  // GoogleSignIn googleSignIn = GoogleSignIn(
  //   scopes: [
  //     'email',
  //     'https://www.googleapis.com/auth/userinfo.email',
  //   ],
  //   signInOption: SignInOption.standard,
  // );

  Future<TimeOfDay> getStod(
    String employeeUID,
    String employerUID,
  ) async {
    TimeOfDay stod = const TimeOfDay(hour: 9, minute: 0);
    try {
      DocumentSnapshot ds = await ff
          .collection("1BotUsers")
          .doc(employerUID)
          .collection("Employees")
          .doc(employeeUID)
          .get();
      DateTime res = ds["stod"].toDate();
      stod = TimeOfDay(hour: res.hour, minute: res.minute);
    } catch (e) {
      debugPrint(e.toString());
    }
    return stod;
  }

  Future<QuerySnapshot> getRecords(
    String employeeUID,
    String employerUID,
    String month,
  ) async {
    return await ff
        .collection("1BotUsers")
        .doc(employerUID)
        .collection("Employees")
        .doc(employeeUID)
        .collection(month)
        .get();
  }

  Future<DocumentSnapshot> fetchUserFromFaidepro(String uID) async {
    return await ff.collection("1AllUsers").doc(uID).get();
  }

  Future<DocumentSnapshot> fetchUserFromBot(
    String employerUID,
    String uID,
  ) async {
    return await ff
        .collection("1BotUsers")
        .doc(employerUID)
        .collection("Employees")
        .doc(uID)
        .get();
  }

  Future<DocumentSnapshot> fetchEmployee(
    String employeeUID,
    String employerUID,
  ) async {
    return await ff
        .collection("1BotUsers")
        .doc(employerUID)
        .collection("Employees")
        .doc(employeeUID)
        .get();
  }

  Future<List<DocumentSnapshot>> fetchEmployees(
    String uID,
  ) async {
    return (await ff
            .collection("1BotUsers")
            .doc(uID)
            .collection("Employees")
            .get())
        .docs;
  }

  Future<String?> checkIfUserExists(String uID) async {
    QuerySnapshot allEmployers = await ff.collection("1BotUsers").get();
    for (DocumentSnapshot employer in allEmployers.docs) {
      try {
        QuerySnapshot allEmployees = await ff
            .collection("1BotUsers")
            .doc(employer.id)
            .collection("Employees")
            .get();
        for (DocumentSnapshot employee in allEmployees.docs) {
          if (employee.id == uID) return employer.id;
        }
      } catch (e) {
        debugPrint("not associated with this employer");
      }
    }
    return null;
  }

  Future<DocumentSnapshot> fetchUserBotInfo(String uID) async {
    return await ff.collection("1AllUsers").doc(uID).get();
  }

  Future<String> fetchEmployerName(String uID) async {
    try {
      DocumentSnapshot ds = await ff.collection("1AllUsers").doc(uID).get();
      return ds["name"];
    } catch (e) {
      return "NA";
    }
  }

  Future<bool> isBotAdmin(String uID) async {
    return (await ff.collection("1BotUsers").doc(uID).get()).exists;
  }

  // Future handleEmployeeLogin(
  //   String employerUID,
  //   String employerName, {
  //   required LoginProvider lp,
  //   required bool mounted,
  //   required BuildContext context,
  // }) async {
  //   if (lp.isVerified) {
  //     employerUID = employerUID.trim();
  //     lp.startProcessing();
  //     DocumentSnapshot ds = await fetchUserFromBot(
  //       employerUID,
  //       lp.phone,
  //     );
  //     Map<String, dynamic> map = {
  //       "name": ds["name"],
  //       "email": "",
  //       "profileImageUrl": "",
  //       "uID": lp.phone,
  //       "isAdmin": false,
  //       "employerName": employerName.trim(),
  //       "employerUID": employerUID,
  //     };
  //     MySharedPreferences msp = MySharedPreferences();
  //     await msp.setPreferences(map);
  //     if (mounted) {
  //       Provider.of<Statistics>(context, listen: false).clear();
  //       Provider.of<Statistics>(context, listen: false).getStatistics();
  //       Navigation(context).pushReplacement(const Welcome());
  //     }
  //   }
  // }

  // Future<String> handleAdminLogin(
  //   String uID, {
  //   required bool mounted,
  //   required BuildContext context,
  //   String? employerUID,
  //   String? employerName,
  // }) async {
  //   if (employerUID == null) {
  //     try {
  //       DocumentSnapshot ds = await fetchUserFromFaidepro(uID);
  //       Map<String, dynamic> map = {
  //         "name": ds["name"],
  //         "email": ds["email"],
  //         "profileImageUrl": ds["profileImageUrl"],
  //         "uID": ds["uID"],
  //         "isAdmin": true,
  //         "employerName": ds["name"],
  //         "employerUID": ds["uID"],
  //       };
  //       msp.setPreferences(map);
  //       if (mounted) {
  //         Navigation nav = Navigation(context);
  //         nav.pushReplacement(nav.getMainScreenChild(true));
  //       }
  //       return "Login success.";
  //     } catch (e) {
  //       return "Something went wrong";
  //     }
  //   } else {
  //     try {
  //       DocumentSnapshot ds = await fetchUserFromBot(employerUID, uID);
  //       Map<String, dynamic> map = {
  //         "name": ds["name"],
  //         "email": "",
  //         "profileImageUrl": "",
  //         "uID": ds["uID"],
  //         "isAdmin": true,
  //         "employerName": employerName,
  //         "employerUID": employerUID,
  //       };
  //       msp.setPreferences(map);
  //       if (mounted) {
  //         Navigation nav = Navigation(context);
  //         nav.pushReplacement(nav.getMainScreenChild(true));
  //       }
  //       return "Login successfull.";
  //     } catch (e) {
  //       return "Something went wrong";
  //     }
  //   }
  // }

  Future<bool> verifyEmployer(String name, String uID) async {
    DocumentSnapshot ds = await userInfo.doc(uID).get();
    if (ds.exists && ds["name"] == name) {
      return true;
    }
    return false;
  }

  Future<bool> verifyEmployerWithEmployee({
    required String employerUID,
    required String employeeUID,
  }) async {
    try {
      //get employee details and cross reference
      DocumentSnapshot employee = await userBotInfo
          .doc(employerUID)
          .collection("Employees")
          .doc(employeeUID)
          .get();
      if (employee.exists) {
        return true;
      }
    } catch (e) {
      debugPrint("Employee doesn't exist");
    }
    return false;
  }

  // signout(BuildContext context) {
  //   googleSignIn.signOut();
  //   fa.signOut();
  //   Provider.of<LoginProvider>(context, listen: false).reset();
  //   MySharedPreferences().clear();
  //   Provider.of<Statistics>(context, listen: false).clear();
  //   Navigation(context).pushAndRemoveUntil(const SplashScreen());
  // }
}
