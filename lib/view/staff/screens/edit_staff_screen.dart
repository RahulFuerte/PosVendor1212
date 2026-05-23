import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/utils/error_utils.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/home/navigation.dart';

class EditStaffScreen extends StatefulWidget {
  final UserModel staff;

  const EditStaffScreen({super.key, required this.staff});

  @override
  State<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends State<EditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff.name);
    _phoneController = TextEditingController(text: widget.staff.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      };

      await UserService().updateStaff(widget.staff.id!, updates);

        if (mounted) {
          SnackBarUtils.showSuccess(context, AppLocale.staffUpdatedSuccess.getString(context));
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
          text: AppLocale.editStaff.getString(context),
          fontWeight: FontWeight.w600,
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
                  onPressed: _isLoading ? null : _updateStaff,
                  child: _isLoading
                      ? Transform.scale(
                          scale: 0.5,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      : MyText(
                          text: AppLocale.updateStaff.getString(context),
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
