// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/cloudinary_service.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditBillReceiptScreen extends StatefulWidget {
  final String AdminUid;
  final String phoneNo;

  const EditBillReceiptScreen({
    Key? key,
    required this.AdminUid,
    required this.phoneNo,
  }) : super(key: key);

  @override
  State<EditBillReceiptScreen> createState() => _EditBillReceiptScreenState();
}

class _EditBillReceiptScreenState extends State<EditBillReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _fssaiNumberController = TextEditingController();
  final _upiIdController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _storageService = CloudinaryService();

  bool _isSaving = false;
  bool _isLoading = true;
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final sqliteData = await SQLiteHelper().getUserData(widget.phoneNo);
      final prefs = await SharedPreferences.getInstance();

      if (sqliteData != null) {
        _shopNameController.text = sqliteData['shopName'] ?? '';
        _contactController.text = sqliteData['shopContact'] ?? '';
        _addressController.text = sqliteData['address'] ?? '';
        _gstNumberController.text = sqliteData['gstNumber'] ?? '';
        _fssaiNumberController.text = sqliteData['fssaiNo'] ?? '';
        _upiIdController.text = sqliteData['upiId'] ?? '';
        _imageUrl = sqliteData['shopLogoUrl'];
      } else {
        // Fallback to SharedPreferences if SQLite is empty
        _shopNameController.text = prefs.getString('shopName') ?? '';
        _contactController.text = prefs.getString('contact') ?? '';
        _addressController.text = prefs.getString('address') ?? '';
        _gstNumberController.text = prefs.getString('gstNumber') ?? '';
        _fssaiNumberController.text = prefs.getString('fssaiNo') ?? '';
        _upiIdController.text = prefs.getString('upiId') ?? '';
        _imageUrl = prefs.getString('logoUrl');
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadImageAndSave() async {
    debugPrint('Starting image upload process...');
    if (_imageFile == null) {
      debugPrint('No image file selected, skipping upload');
      return;
    }

    try {
      debugPrint('Image file path: ${_imageFile!.path}');
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        debugPrint('Deleting old image at URL: $_imageUrl');
        await _storageService.deleteImage(_imageUrl!);
      }

      debugPrint('Uploading new image to Firebase Storage...');
      _imageUrl = await _storageService.uploadImage(_imageFile!, 'profile');
      debugPrint('Upload complete! New image URL: $_imageUrl');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _uploadImageAndSave();

      final prefs = await SharedPreferences.getInstance();

      // 1. Save to SharedPreferences
      await prefs.setString('shopName', _shopNameController.text.trim());
      await prefs.setString('contact', _contactController.text.trim());
      await prefs.setString('address', _addressController.text.trim());
      await prefs.setString('gstNumber', _gstNumberController.text.trim());
      await prefs.setString('fssaiNo', _fssaiNumberController.text.trim());
      await prefs.setString('upiId', _upiIdController.text.trim());
      await prefs.setString('logoUrl', _imageUrl ?? "");

      // 2. Save to SQLite
      await SQLiteHelper().saveUserData({
        'phone_number': widget.phoneNo,
        'admin_uid': widget.AdminUid,
        'shop_name': _shopNameController.text.trim(),
        'shop_contact': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'gst_number': _gstNumberController.text.trim(),
        'fssaiNo': _fssaiNumberController.text.trim(),
        'upiId': _upiIdController.text.trim(),
        'shop_logo_url': _imageUrl ?? "",
      });

      // 3. Save to MongoDB (Sync Profile)
      await UserService().updateProfile({
        'name': prefs.getString('name') ?? "", // Maintain current user name
        'phoneNumber': widget.phoneNo,
        'shopName': _shopNameController.text.trim(),
        'address': _addressController.text.trim(),
        'gstNo': _gstNumberController.text.trim(),
        'fssaiNo': _fssaiNumberController.text.trim(),
        'logoUrl': _imageUrl ?? "",
        'logo_url': _imageUrl ?? "", // Backend fallback
        'shopLogoUrl': _imageUrl ?? "", // Backend fallback
        'upiId': _upiIdController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: MyText(text: 'Settings saved successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: MyText(text: 'Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const MyText(
                text: 'Select Logo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  if (_imageFile != null || _imageUrl != null)
                    _buildImageSourceOption(
                      icon: Icons.delete,
                      label: 'Remove',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _imageFile = null;
                          _imageUrl = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color ?? primaryColor),
            const SizedBox(height: 8),
            MyText(
              text: label,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageUrl = null; // Clear old URL when new image is selected
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: 'Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _gstNumberController.dispose();
    _fssaiNumberController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const MyText(
          text: 'Edit Bill Receipt',
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo Section
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.white,
                                      child: _imageFile != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _imageFile!,
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : _imageUrl != null && _imageUrl!.trim().isNotEmpty
                                              ? ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl: _imageUrl!,
                                                    width: 120,
                                                    height: 120,
                                                    fit: BoxFit.contain,
                                                    placeholder: (context, url) => const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                    errorWidget: (context, url, error) => Icon(
                                                      Icons.store,
                                                      size: 50,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.store,
                                                  size: 50,
                                                  color: Colors.grey[400],
                                                ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _showImageSourceDialog,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: MyText(
                                text: 'Add Shop Logo',
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Form Header
                            const MyText(
                              text: 'Receipt Details',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            const SizedBox(height: 8),
                            MyText(
                              text: 'Please fill in the information below',
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 24),

                            // Shop Name Field
                            _buildTextField(
                              controller: _shopNameController,
                              label: 'Shop Name',
                              hint: 'Enter shop name',
                              icon: Icons.store,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter shop name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Contact Field
                            _buildTextField(
                              controller: _contactController,
                              label: 'Contact',
                              hint: 'Enter 10 digit number',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              prefixText: '+91 ',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter contact number';
                                }
                                if (value.length != 10) {
                                  return 'Contact number must be 10 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // GST Number Field
                            _buildTextField(
                                controller: _gstNumberController,
                                label: 'GST Number',
                                hint: 'GST number',
                                icon: Icons.receipt_long,
                                inputFormatters: [
                                  UpperCaseTextFormatter(),
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                validator: (value) {
                                  // GST number is optional
                                  if (value != null && value.isNotEmpty) {
                                    // final gstRegex = RegExp(
                                    //     r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                                    // if (!gstRegex.hasMatch(value.toUpperCase())) {
                                    //   return 'Please enter a valid GST number';
                                    // }
                                    if (value.length != 15) {
                                      return 'GST number must be 15 characters';
                                    }
                                    return null;
                                  }
                                  return null;
                                }),
                            const SizedBox(height: 16),

                            // Fssai License Number Field
                            _buildTextField(
                              controller: _fssaiNumberController,
                              label: 'Fssai Number',
                              hint: 'Enter fssai license number',
                              icon: Icons.verified_outlined,
                              validator: (value) {},
                            ),
                            const SizedBox(height: 16),

                            // Fssai License Number Field
                            _buildTextField(
                              controller: _upiIdController,
                              label: 'Upi Id',
                              hint: 'Enter upi id number',
                              icon: Icons.qr_code_outlined,
                              validator: (value) {},
                            ),
                            const SizedBox(height: 16),

                            // Address Field
                            _buildTextField(
                              controller: _addressController,
                              label: 'Address',
                              hint: 'Enter complete address',
                              icon: Icons.location_on,
                              maxLines: 4,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const SizedBox(height: 32),

                            // Tax Settings Section
                            const MyText(
                              text: 'Tax Settings',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            const SizedBox(height: 8),
                            MyText(
                              text: 'Configure tax display on receipts',
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),

                            // Tax Settings Card
                            Consumer<PrintProvider>(
                              builder: (context, printProvider, child) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    children: [
                                      // Enable Tax Toggle
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.percent, color: primaryColor),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const MyText(
                                                    text: 'Enable Tax on Receipt',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  MyText(
                                                    text: printProvider.taxEnabled
                                                        ? 'Tax will be shown'
                                                        : 'Tax will not be shown',
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Switch(
                                            value: printProvider.taxEnabled,
                                            onChanged: (value) {
                                              printProvider.setTaxEnabled(value);
                                            },
                                            activeColor: primaryColor,
                                          ),
                                        ],
                                      ),

                                      // Tax Rate Fields (only show when enabled)
                                      if (printProvider.taxEnabled) ...[
                                        const Divider(height: 24),
                                        _buildTaxRateField(
                                          label: 'CGST Rate',
                                          value: printProvider.cgstPercent,
                                          onChanged: (value) {
                                            final cgst = double.tryParse(value) ?? 2.5;
                                            printProvider.setTaxRates(cgst, printProvider.sgstPercent);
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildTaxRateField(
                                          label: 'SGST Rate',
                                          value: printProvider.sgstPercent,
                                          onChanged: (value) {
                                            final sgst = double.tryParse(value) ?? 2.5;
                                            printProvider.setTaxRates(printProvider.cgstPercent, sgst);
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline, color: primaryColor, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: MyText(
                                                  text:
                                                      'Total Tax: ${PriceUtils.formatPrice(printProvider.cgstPercent + printProvider.sgstPercent).substring(1)}%',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Save Button at Bottom
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          disabledBackgroundColor: Colors.grey[400],
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  MyText(
                                    text: 'Save Receipt',
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyText(
          text: label,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          style: TextStyle(fontFamily: "Outfit", fontWeight: FontWeight.w600),
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: "Outfit", fontWeight: FontWeight.w500, color: Colors.grey[400]),
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: maxLines > 1 ? 60 : 0),
              child: Icon(icon, color: primaryColor),
            ),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            alignLabelWithHint: true,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTaxRateField({
    required String label,
    required double value,
    required Function(String) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: MyText(
            text: label,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          flex: 1,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              suffixText: '%',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// Custom formatter to convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
