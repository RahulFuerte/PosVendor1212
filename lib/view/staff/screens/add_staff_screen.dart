import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/utils/error_utils.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/home/navigation.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await UserService().createStaff({
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        if (_passwordController.text.trim().isNotEmpty) 'password': _passwordController.text.trim(),
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, AppLocale.staffAddedSuccess.getString(context));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getCleanErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _cardField({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(
            text: label,
            fontSize: 14,
            color: appbar1,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FA),
      appBar: AppBar(
        title: MyText(
          text: AppLocale.addStaff.getString(context),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _cardField(
                      label: '${AppLocale.fullName.getString(context)} *',
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: AppLocale.enterStaffName.getString(context),
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocale.nameRequired.getString(context);
                          }
                          return null;
                        },
                      ),
                    ),
                    _cardField(
                      label: '${AppLocale.mobileNumber.getString(context)} *',
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: AppLocale.enter10DigitPhone.getString(context),
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocale.phoneRequired.getString(context);
                          }
                          if (value.trim().length != 10) {
                            return AppLocale.mobileNumberMustBe10Digits.getString(context);
                          }
                          return null;
                        },
                      ),
                    ),
                    // Login credentials section header
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 15, color: appbar1),
                          SizedBox(width: 6),
                          MyText(
                            text: 'Login Credentials (Optional)',
                            fontSize: 13,
                            color: appbar1,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                    _cardField(
                      label: 'Password',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Set a password for this staff',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    _cardField(
                      label: 'Confirm Password',
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Re-enter the password',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) {
                          if (_passwordController.text.trim().isNotEmpty) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm the password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    // Credential hint card
                    if (_phoneController.text.isNotEmpty && _passwordController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: appbar1.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: appbar1.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 15, color: appbar1),
                                SizedBox(width: 6),
                                MyText(
                                  text: 'Staff Login Details',
                                  fontSize: 13,
                                  color: appbar1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                MyText(text: 'Phone: ', fontSize: 13, color: Colors.grey.shade600),
                                MyText(text: _phoneController.text, fontSize: 13, fontWeight: FontWeight.w600),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                MyText(text: 'Password: ', fontSize: 13, color: Colors.grey.shade600),
                                MyText(text: _passwordController.text, fontSize: 13, fontWeight: FontWeight.w600),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MyText(
                              text: 'Share these details with your staff member to log in.',
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbar1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _saveStaff,
                  child: _isLoading
                      ? Transform.scale(
                          scale: 0.5,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      : MyText(
                          text: AppLocale.addStaff.getString(context),
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
