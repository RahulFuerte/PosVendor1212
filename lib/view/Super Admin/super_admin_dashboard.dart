import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/view/login/screens/inception_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      // 🔹 Gradient AppBar
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Super Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('AllAdmins')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          int totalAdmins = docs.length;
          int activeSubscriptions = 0;
          int trialUsers = 0;
          int expiredUsers = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final expiry = (data['expiryDate'] as Timestamp?)?.toDate();
            final package = data['package'] ?? 'trial';

            if (expiry != null && expiry.isAfter(now)) {
              if (package == 'trial') {
                trialUsers++;
              } else {
                activeSubscriptions++;
              }
            } else {
              expiredUsers++;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Stats Cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StatCard(
                      title: 'Total Admins',
                      value: totalAdmins.toString(),
                      icon: Icons.admin_panel_settings,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      title: 'Active Subscriptions',
                      value: activeSubscriptions.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Trial Users',
                      value: trialUsers.toString(),
                      icon: Icons.timer,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      title: 'Expired',
                      value: expiredUsers.toString(),
                      icon: Icons.cancel,
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 🔹 Admin List Title
                const Text(
                  'Admins',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                // 🔹 Admin List
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text("No admins found"))
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Shop Keeper';
                            final phone = data['phone'] ?? 'No Phone';
                            final adminCode = data['adminCode'] ?? 'No Code';
                            final expiry =
                                (data['expiryDate'] as Timestamp?)?.toDate();
                            final package = data['package'] ?? 'trial';

                            AdminStatus status;
                            if (expiry != null && expiry.isAfter(now)) {
                              status = package == 'trial'
                                  ? AdminStatus.trial
                                  : AdminStatus.active;
                            } else {
                              status = AdminStatus.expired;
                            }

                            return _AdminTile(
                              adminName: "$name ($adminCode)",
                              phone: phone,
                              totalCustomers:
                                  0, // Need to fetch separately if needed
                              status: status,
                              onTap: () {
                                // 👉 Navigate to specific admin details if needed
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
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

//
// =========================
// 🔹 STAT CARD
// =========================
//

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.85), color],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

//
// =========================
// 🔹 ADMIN TILE
// =========================
//

enum AdminStatus { active, trial, expired }

class _AdminTile extends StatelessWidget {
  final String adminName;
  final String phone;
  final int totalCustomers;
  final AdminStatus status;
  final VoidCallback onTap;

  const _AdminTile({
    required this.adminName,
    required this.phone,
    required this.totalCustomers,
    required this.status,
    required this.onTap,
  });

  Color get statusColor {
    switch (status) {
      case AdminStatus.trial:
        return Colors.orange;
      case AdminStatus.expired:
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  String get statusText {
    switch (status) {
      case AdminStatus.trial:
        return 'TRIAL';
      case AdminStatus.expired:
        return 'EXPIRED';
      default:
        return 'ACTIVE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: const Icon(Icons.store, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalCustomers Customers',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
