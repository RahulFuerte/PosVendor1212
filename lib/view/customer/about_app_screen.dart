import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const MyText(
          text: 'About App',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // APP LOGO / ICON
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor,
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
                  const SizedBox(height: 24),
                  const MyText(
                    text: "Billing Sphere",
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                  const MyText(
                    text: "Version 1.0.0 (Stable)",
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 40),

                  // DESCRIPTION
                  const MyText(
                    text: "Smart POS solution for modern restaurant management.",
                    fontSize: 15,
                    color: Colors.black87,
                    textAlign: TextAlign.center,
                    height: 1.6,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 48),

                  // LEGAL LINKS
                  _buildLegalItem(
                    icon: Icons.description_outlined,
                    title: "Terms and Conditions",
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildLegalItem(
                    icon: Icons.privacy_tip_outlined,
                    title: "Privacy Policy",
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildLegalItem(
                    icon: Icons.code_rounded,
                    title: "Open Source Licenses",
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // COPYRIGHT FOOTER
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const MyText(
                  text: "© 2026 Billing Sphere",
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 4),
                MyText(
                  text: "Made with passion for the restaurant industry.",
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: MyText(
                text: title,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
