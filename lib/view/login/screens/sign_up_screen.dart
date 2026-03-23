import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _shopCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _fssaiCtrl.dispose();
    _gstCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _userService.registerAdmin(
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        shopName: _shopCtrl.text.trim().isEmpty ? null : _shopCtrl.text.trim(),
        fssaiNo: _fssaiCtrl.text.trim().isEmpty ? null : _fssaiCtrl.text.trim(),
        gstNo: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
      );

      if (!mounted) return;
      _snack('Account created successfully!', Colors.green.shade700);

      // Navigate to main app, remove all previous routes
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _shopCtrl.clear();
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _fssaiCtrl.clear();
      _gstCtrl.clear();
      _upiCtrl.clear();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _snack(
          e.toString().replaceAll('Exception: ', '').replaceAll('Registration error: ', ''),
          Colors.red.shade600,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: MyText(
        text: msg,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Logo area
          Stack(
            children: [
              Container(
                color: Colors.white,
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Image.asset(
                    'assets/images/myBillLogo.png',
                    fit: BoxFit.contain,
                    height: 110,
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),

          // Form card
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
                ],
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const MyText(
                        text: 'Create Account',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 4),
                      MyText(
                        text: 'Register to start using the POS',
                        color: Colors.grey.shade500,
                        fontSize: 13.5,
                      ),

                      const SizedBox(height: 28),

                      // ── Name ──────────────────────────────────────────────
                      _label('Full Name *'),
                      _textField(
                        controller: _nameCtrl,
                        hint: 'e.g. Rahul Sharma',
                        icon: Icons.person_outline_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Phone ─────────────────────────────────────────────
                      _label('Phone Number *'),
                      _textField(
                        controller: _phoneCtrl,
                        hint: '10-digit mobile number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Phone is required';
                          if (v.trim().length != 10) return 'Enter a valid 10-digit number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Shop Name ─────────────────────────────────────────
                      _label('Shop / Restaurant Name'),
                      _textField(
                        controller: _shopCtrl,
                        hint: 'e.g. Spice Garden (optional)',
                        icon: Icons.storefront_outlined,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // ── FSSAI No ──────────────────────────────────────────
                      _label('FSSAI No'),
                      _textField(
                        controller: _fssaiCtrl,
                        hint: 'e.g. 12345678901234 (optional)',
                        icon: Icons.assignment_outlined,
                      ),
                      const SizedBox(height: 16),

                      // ── GST No ────────────────────────────────────────────
                      _label('GST No'),
                      _textField(
                        controller: _gstCtrl,
                        hint: 'e.g. 22AAAAA0000A1Z5 (optional)',
                        icon: Icons.receipt_long_outlined,
                        capitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),

                      // ── UPI ID ────────────────────────────────────────────
                      _label('UPI ID'),
                      _textField(
                        controller: _upiCtrl,
                        hint: 'e.g. user@upi (optional)',
                        icon: Icons.payment_outlined,
                      ),
                      const SizedBox(height: 16),

                      // ── Password ──────────────────────────────────────────
                      _label('Password *'),
                      _textField(
                        controller: _passwordCtrl,
                        hint: 'Minimum 6 characters',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Confirm Password ──────────────────────────────────
                      _label('Confirm Password *'),
                      _textField(
                        controller: _confirmPasswordCtrl,
                        hint: 'Re-enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // ── Register Button ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const MyText(
                                  text: 'Create Account',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Back to login ─────────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13.5, color: Colors.black54),
                              children: [
                                const TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Sign In',
                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MyText(
          text: text,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        counterText: '',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}
