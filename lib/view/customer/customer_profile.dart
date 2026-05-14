import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/core/utils/snackbar_utils.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('name') ?? '';
    _phoneController.text = prefs.getString('phoneNumber') ?? '';
    _cityController.text = prefs.getString('city') ?? '';
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text.trim());
      await prefs.setString('phoneNumber', _phoneController.text.trim());
      await prefs.setString('city', _cityController.text.trim());
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Unable to save profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const MyText(text: 'Profile', fontSize: 20, fontWeight: FontWeight.w900),
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // PROFILE AVATAR SECTION
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200, width: 4),
                          ),
                          child: const Icon(Icons.person_outline_rounded, size: 50, color: Colors.grey),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: MyText(
                      text: _nameController.text.isEmpty ? 'Guest Member' : _nameController.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Center(
                    child: MyText(
                      text: _phoneController.text.isEmpty ? '+91 00000 00000' : _phoneController.text,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 40),

                  _sectionLabel('PERSONAL INFORMATION'),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTransparentField(
                            label: 'Full Name', controller: _nameController, icon: Icons.person_outline),
                        const SizedBox(height: 20),
                        _buildTransparentField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            icon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        _buildTransparentField(label: 'City', controller: _cityController, icon: Icons.map_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const MyText(
                              text: 'Update Profile',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return MyText(
      text: text,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade400,
      letterSpacing: 1.2,
    );
  }

  Widget _buildTransparentField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyText(text: label, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black45, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          validator: (value) => (value == null || value.isEmpty) ? 'Please enter $label' : null,
        ),
      ],
    );
  }
}
