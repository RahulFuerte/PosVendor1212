import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const MyText(
          text: 'Help & Support',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SUPPORT HEADER CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: "How can we help today?",
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                  SizedBox(height: 8),
                  MyText(
                    text: "Search our FAQs or contact our support team directly.",
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // CONTACT OPTIONS
            const MyText(
              text: "Direct Support",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildContactCircle(
                  icon: Icons.phone_rounded,
                  label: "Call Us",
                  onTap: () => _launchUrl("tel:+919999999999"),
                ),
                const SizedBox(width: 12),
                _buildContactCircle(
                  icon: Icons.chat_bubble_rounded,
                  label: "WhatsApp",
                  onTap: () => _launchUrl("https://wa.me/919999999999"),
                  color: const Color(0xFF25D366),
                ),
                const SizedBox(width: 12),
                _buildContactCircle(
                  icon: Icons.email_rounded,
                  label: "Email",
                  onTap: () => _launchUrl("mailto:support@example.com"),
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // FAQ SECTION
            const MyText(
              text: "Frequently Asked Questions",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              "How to track my order?",
              "You can track your order status in the 'My Orders' section of the Settings tab. You will also receive notifications when your order is ready.",
            ),
            _buildFaqItem(
              "Available payment methods?",
              "We support various payment methods including Cash, UPI, Card, and Net Banking depending on the restaurant's configuration.",
            ),
            _buildFaqItem(
              "Can I cancel my order?",
              "Order cancellation depends on the restaurant's policy. Please contact the restaurant directly using the contact details provided in the order summary.",
            ),
            _buildFaqItem(
              "How to edit my profile?",
              "Go to Settings > My Profile to update your name, phone number, and other details.",
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCircle({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = primaryColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              MyText(
                text: label,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: MyText(
            text: question,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Outfit',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: primaryColor,
          children: [
            MyText(
              text: answer,
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
