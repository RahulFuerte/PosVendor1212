import 'package:flutter/material.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/login/screens/new_admin_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class RoleSelectionScreen extends StatelessWidget {
  final String phone;
  const RoleSelectionScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_circle,
                size: 100,
                color: primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                "Select Login Role",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Logged in as $phone",
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              _RoleButton(
                title: "Login as Admin",
                subtitle: "Manage shop, products, and reports",
                icon: Icons.admin_panel_settings,
                color: primaryColor,
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const NewAdminScreen()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 16),
              _RoleButton(
                title: "Login as User",
                subtitle: "Place orders and view menu",
                icon: Icons.person,
                color: Colors.blue,
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => Navigation(uId: phone)),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
