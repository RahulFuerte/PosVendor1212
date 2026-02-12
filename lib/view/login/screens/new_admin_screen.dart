import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos/view/login/screens/inception_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewAdminScreen extends StatelessWidget {
  const NewAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Admin Dashboard"),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text("Welcome, New Admin!"),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text(
                  "Are you sure you want to logout?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('isLogged', false);
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Login()),
                          );
                        }
                      },
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
