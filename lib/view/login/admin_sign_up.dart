// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/l10n/app_locale.dart';
// import 'package:pos/view/home/navigation.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class AdminSignUp extends StatefulWidget {
  const AdminSignUp({super.key});

  @override
  State<AdminSignUp> createState() => _AdminSignUpState();
}

class _AdminSignUpState extends State<AdminSignUp> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _shopCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _businessCategory = 'Food';
  final List<String> _categories = ['Food', 'Retail'];

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _shopCtrl.dispose();
    _fssaiCtrl.dispose();
    _gstCtrl.dispose();
    _upiCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  String _categoryLabel(String code) {
    switch (code) {
      case 'Retail':
        return AppLocale.retail.getString(context);
      default:
        return AppLocale.food.getString(context);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final phone = _phoneCtrl.text.trim();

    try {
      await UserService().registerAdmin(
        name: _nameCtrl.text.trim(),
        phoneNumber: phone,
        password: _passwordCtrl.text.trim(),
        shopName: _shopCtrl.text.trim(),
        fssaiNo: _fssaiCtrl.text.trim().isEmpty ? null : _fssaiCtrl.text.trim(),
        gstNo: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        businessCategory: _businessCategory,
        businessIcon: _getDefaultIcon(_businessCategory),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _snack(AppLocale.registrationSuccessful.getString(context), Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (color == Colors.green) {
      SnackBarUtils.showSuccess(context, msg);
    } else if (color == Colors.red) {
      SnackBarUtils.showError(context, msg);
    } else {
      SnackBarUtils.showInfo(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: MyText(
          text: AppLocale.shopOwnerRegistration.getString(context),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: AppLocale.businessDetails.getString(context),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 8),
                      MyText(
                        text: AppLocale.setupShopMsg.getString(context),
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      const SizedBox(height: 24),
                      _label('${AppLocale.fullName.getString(context)} *'),
                      _textField(
                        controller: _nameCtrl,
                        hint: AppLocale.egRahulSharma.getString(context),
                        icon: Icons.person_outline_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? AppLocale.nameRequired.getString(context) : null,
                      ),
                      const SizedBox(height: 16),
                      _label('${AppLocale.mobileNumber.getString(context)} *'),
                      _textField(
                        controller: _phoneCtrl,
                        hint: AppLocale.tenDigitMobile.getString(context),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return AppLocale.phoneIsRequired.getString(context);
                          if (v.trim().length != 10) return AppLocale.enterValid10Digit.getString(context);
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('${AppLocale.password.getString(context)} *'),
                      _textField(
                        controller: _passwordCtrl,
                        hint: AppLocale.chooseSecurePassword.getString(context),
                        icon: Icons.lock_outlined,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return AppLocale.passwordIsRequired.getString(context);
                          if (v.trim().length < 6) return AppLocale.passwordMinChars.getString(context);
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('${AppLocale.confirmPasswordLabel.getString(context)} *'),
                      _textField(
                        controller: _confirmPasswordCtrl,
                        hint: AppLocale.confirmPasswordHint.getString(context),
                        icon: Icons.lock_outlined,
                        obscure: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return AppLocale.confirmPasswordIsRequired.getString(context);
                          }
                          if (v.trim() != _passwordCtrl.text.trim()) {
                            return AppLocale.passwordsDoNotMatch.getString(context);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label(AppLocale.shopRestaurantName.getString(context)),
                      _textField(
                        controller: _shopCtrl,
                        hint: AppLocale.egSpiceGarden.getString(context),
                        icon: Icons.storefront_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return AppLocale.shopNameIsRequired.getString(context);
                          return null;
                        },
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _label('${AppLocale.businessCategoryLabel.getString(context)} *'),
                      _categoryDropdown(),
                      const SizedBox(height: 16),
                      _label(AppLocale.fssaiNoLabel.getString(context)),
                      _textField(
                        controller: _fssaiCtrl,
                        hint: AppLocale.egFssai.getString(context),
                        icon: Icons.assignment_outlined,
                      ),
                      const SizedBox(height: 16),
                      _label(AppLocale.gstNoLabel.getString(context)),
                      _textField(
                        controller: _gstCtrl,
                        hint: AppLocale.egGst.getString(context),
                        icon: Icons.receipt_long_outlined,
                        capitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      _label(AppLocale.upiIdLabel.getString(context)),
                      _textField(
                        controller: _upiCtrl,
                        hint: AppLocale.egUpi.getString(context),
                        icon: Icons.payment_outlined,
                      ),
                      const SizedBox(height: 16),
                      _label('${AppLocale.cityLabel.getString(context)} *'),
                      _textField(
                        controller: _cityCtrl,
                        hint: AppLocale.egRajkot.getString(context),
                        icon: Icons.location_city_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? AppLocale.cityIsRequired.getString(context) : null,
                      ),
                      const SizedBox(height: 16),
                      _label('${AppLocale.detailedAddressLabel.getString(context)} *'),
                      _textField(
                        controller: _addressCtrl,
                        hint: AppLocale.egAddress.getString(context),
                        icon: Icons.map_outlined,
                        capitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? AppLocale.addressIsRequired.getString(context) : null,
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(color: Colors.white))
                              : MyText(
                                  text: AppLocale.registerLabel.getString(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _categoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _businessCategory,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
          items: _categories.map((String category) {
            return DropdownMenuItem(
              value: category,
              child: MyText(
                text: _categoryLabel(category),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _businessCategory = newValue);
            }
          },
        ),
      ),
    );
  }

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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 13.5, fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
        errorStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
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

  String _getDefaultIcon(String category) {
    switch (category) {
      case 'Retail':
        return 'shopping_bag';
      default:
        return 'restaurant';
    }
  }
}
