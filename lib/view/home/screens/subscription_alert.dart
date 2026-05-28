import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/screens/subscription_plans_screen.dart';

// These Page Is For Showing Subscription Expired Alert To User

class SubscriptionAlert extends StatelessWidget {
  const SubscriptionAlert({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: appbar1.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:  const Icon(
                    Icons.block,
                    size: 60,
                    color: appbar1,
                  ),
                ),

                const SizedBox(height: 24),

                 const MyText(
                  text: 'Subscription Expired',
                  textAlign: TextAlign.center,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appbar1,
                ),

                const SizedBox(height: 12),

                // ℹ️ Message
                const MyText(
                  text: 'Your subscription has expired.\n'
                      'Please contact the administrator to renew your plan.',
                  textAlign: TextAlign.center,
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const MyText(
                      text: 'Reactivate / Upgrade Plan',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appbar1,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionPlansScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
