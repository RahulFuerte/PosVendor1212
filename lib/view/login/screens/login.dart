import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos/view/login/screens/sign_up_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/snack_bar.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/Super Admin/super_admin_dashboard.dart';
import 'package:pos/view/login/screens/new_admin_screen.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.length != 10) {
      CustomSnackBar(context).build("Enter a valid 10-digit phone number.");
      return;
    }
    if (password.isEmpty) {
      CustomSnackBar(context).build("Password cannot be empty.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final UserModel user = await UserService().loginUser(
        phoneNumber: phone,
        password: password,
      );

      final String token = user.token ?? '';
      final String role = user.role ?? 'user';
      final String adminUid = user.id ?? phone;

      await _saveSession(
        id: user.id ?? '',
        name: user.name,
        phone: phone,
        token: token,
        role: role,
        adminUid: adminUid,
        shopName: user.shopName ?? '',
        address: user.address ?? '',
        logoUrl: user.logoUrl ?? '',
        gstNo: user.gstNo ?? '',
        fssaiNo: user.fssaiNo ?? '',
        upiId: user.upiId ?? '',
        adminContact: user.adminContact ?? '',
        subscriptionStatus: user.subscription?.status ?? 'inactive',
        subscriptionEndDate: user.subscription?.endDate?.toIso8601String(),
        subscriptionPlanType: user.subscription?.planType ?? 'free',
      );

      Widget nextScreen;
      if (role == 'superAdmin') {
        nextScreen = const SuperAdminDashboard();
      } else {
        nextScreen = Navigation(uId: phone);
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => nextScreen),
          (route) => false,
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      print("These Is The Login Error .................$e");
    }
  }

  Future<void> _enterDemoMode() async {
    setState(() => _isLoading = true);
    try {
      // Mock Demo Data
      const demoPhone = "1234567890";
      const demoId = "demo_admin_123";

      await _saveSession(
        id: demoId,
        name: "Demo User",
        phone: demoPhone,
        token: "demo_token_xyz",
        role: "admin",
        adminUid: demoId,
        shopName: "Demo Restaurant",
        address: "123 Demo Street, Tech City",
        logoUrl: "",
        gstNo: "22AAAAA0000A1Z5",
        fssaiNo: "12345678901234",
        upiId: "demo@upi",
        adminContact: demoPhone,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDemoMode', true);
      await prefs.setString('auth_token', "demo_token_xyz"); // Ensure key matches service expectations

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Navigation(uId: demoPhone)),
          (route) => false,
        );
      }
    } catch (e) {
      print("Demo Mode Error: $e");
      if (mounted) {
        CustomSnackBar(context).build("Failed to enter demo mode.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSession({
    required String id,
    required String name,
    required String phone,
    required String token,
    required String role,
    required String adminUid,
    String shopName = '',
    String adminContact = '',
    String address = '',
    String logoUrl = '',
    String gstNo = '',
    String fssaiNo = '',
    String upiId = '',
    String subscriptionStatus = 'inactive',
    String? subscriptionEndDate,
    String subscriptionPlanType = 'free',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('_id', id);
    await prefs.setString('name', name);
    await prefs.setString('phoneNumber', phone);
    await prefs.setString('token', token);

    // Kept for backward compatibility
    await prefs.setString('myPhone', phone);
    await prefs.setBool('isLogged', true);
    await prefs.setBool('isDemoMode', false); // Disable demo mode for real login
    await prefs.setString('authToken', token);
    await prefs.setString('auth_token', token); // For service compatibility

    await prefs.setString('role', role);
    await prefs.setString('adminUid', adminUid);
    await prefs.setBool('isAdmin', role == 'admin' || role == 'superAdmin');

    await prefs.setString('subscriptionStatus', subscriptionStatus);
    await prefs.setString('subscriptionPlanType', subscriptionPlanType);
    if (subscriptionEndDate != null) {
      await prefs.setString('subscriptionEndDate', subscriptionEndDate);
    }

    if (shopName.isNotEmpty) await prefs.setString('shopName', shopName);
    if (adminContact.isNotEmpty) await prefs.setString('contact', adminContact);
    if (address.isNotEmpty) await prefs.setString('address', address);
    if (logoUrl.isNotEmpty) await prefs.setString('logoUrl', logoUrl);
    if (gstNo.isNotEmpty) await prefs.setString('gstNumber', gstNo);
    if (fssaiNo.isNotEmpty) await prefs.setString('fssaiNo', fssaiNo);
    if (upiId.isNotEmpty) await prefs.setString('upiId', upiId);

    // Sync with SQLite for local persistence across screens
    await SQLiteHelper().saveUserData({
      'phoneNumber': phone,
      'adminUid': adminUid,
      'name': name,
      'shopName': shopName,
      'contact': adminContact,
      'address': address,
      'logoUrl': logoUrl,
      'gstNumber': gstNo,
      'fssaiNo': fssaiNo,
      'upiId': upiId,
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 15),

          // ─── LOGO ────────────────────────────────────────────────────────
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Image.asset(
                "assets/images/myBillLogo.png",
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // ─── LOGIN CARD ──────────────────────────────────────────────────
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const MyText(
                      text: "Welcome Back",
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 6),
                    const MyText(
                      text: "Login with your phone number & password",
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 30),

                    // ─── Phone Number ─────────────────────────────────────
                    _label("Phone Number"),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(letterSpacing: 2, fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "Enter phone number",
                        prefixIcon: Icon(Icons.phone, color: primaryColor),
                        suffixIcon:
                            _phoneController.text.length == 10 ? Icon(Icons.check_circle, color: primaryColor) : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Password ─────────────────────────────────────────
                    _label("Password"),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: "Enter password",
                        prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ─── Login Button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? Transform.scale(
                                scale: 0.6,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const MyText(
                                text: "LOGIN",
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 16,
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUp()),
                        ),
                        child: const MyText(
                          text: "Don't have an account? Sign Up",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          side: BorderSide(color: primaryColor),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _isLoading ? null : _enterDemoMode,
                        icon: Icon(Icons.play_circle_outline, color: primaryColor),
                        label: MyText(
                          text: "TRY DEMO MODE",
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
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
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MyText(text: text, fontWeight: FontWeight.w600, fontSize: 14),
      );
}
