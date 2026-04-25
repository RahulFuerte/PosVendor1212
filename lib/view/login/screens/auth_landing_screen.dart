import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/screens/login.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/view/home/navigation.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withBlue(40).withGreen(140), // Deeper vibrant emerald
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ─── PREMIUM HEADER ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
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
                    const SizedBox(height: 16),
                    // NEW TRY DEMO BUTTON
                    InkWell(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final bool hasVisitedDemo = prefs.getBool('has_visited_demo') ?? false;
                        if (!hasVisitedDemo) {
                          await prefs.setBool('is_first_time_tutorial', true);
                          await prefs.setBool('is_first_time_main_tutorial', true);
                          await prefs.setBool('is_first_time_drawer_tutorial', true);
                          await prefs.setBool('is_first_time_detailed_tutorial', true);
                          await prefs.setBool('has_visited_demo', true);
                        }
                        await prefs.setBool('isDemoMode', true);
                        await prefs.setBool('isLogged', true);
                        await prefs.setString('role', 'admin');
                        await prefs.setString('adminUid', 'demo_admin_123');
                        await prefs.setString('_id', 'demo_admin_123');
                        await prefs.setString('myPhone', '9999999999');
                        await prefs.setString('shopName', 'Billing Spher');
                        await prefs.setString('address', 'MG Road, Bangalore');
                        await prefs.setString('contact', '9999999999');
                        await prefs.setString('upiId', 'merchant@upi');

                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Navigation(uId: 'demo_admin_123', role: 'admin'),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            MyText(
                              text: 'Try Demo',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── SELECTION AREA ────────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MyText(
                          text: 'Welcome Back',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const MyText(
                          text: 'Select Your Account Type',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                        const SizedBox(height: 4),
                        MyText(
                          text: 'Let’s set up your workspace.',
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),

                        const SizedBox(height: 40),

                        // Organization Card
                        _RoleCard(
                          title: 'Organization',
                          subtitle: 'Owner / Staff managing inventory & sales.',
                          icon: Icons.store_rounded,
                          accentColor: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Login(role: 'admin'),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Customer Card
                        _RoleCard(
                          title: 'Customer',
                          subtitle: 'Browse favorite shops & place orders.',
                          icon: Icons.shopping_bag_outlined,
                          accentColor: Colors.blueAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Login(role: 'customer'),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 48),

                        Center(
                          child: Column(
                            children: [
                              MyText(
                                text: "Smart Solutions for Smart Businesses",
                                fontSize: 13,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: accentColor, size: 34),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: title,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 4),
                  MyText(
                    text: subtitle,
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  final Color color;
  const _SmallDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
