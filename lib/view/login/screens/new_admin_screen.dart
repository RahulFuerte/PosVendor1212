// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/screens/login.dart';
import 'package:pos/data/datasources/shared_preferences.dart';

class NewAdminScreen extends StatelessWidget {
  const NewAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MyText(text: "New Admin Dashboard"),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: MyText(text: "Welcome, New Admin!"),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 32),
                ),
                const SizedBox(height: 24),
                const MyText(
                  text: "Confirm Logout",
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 12),
                MyText(
                  text: "Are you sure you want to logout? You will need to login again to access your account.",
                  textAlign: TextAlign.center,
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: MyText(
                          text: "Cancel",
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await MySharedPreferences().clear();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const Login()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const MyText(
                          text: "Logout",
                          fontWeight: FontWeight.bold,
                        ),
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
