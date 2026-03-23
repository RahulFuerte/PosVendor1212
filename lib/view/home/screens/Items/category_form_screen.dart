// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:image_picker/image_picker.dart';

// Project imports:
import 'package:pos/data/models/category_model.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/data/services/cloudinary_service.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class CategoryFormScreen extends StatefulWidget {
  final CategoryModel? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final CategoryService _service = CategoryService();
  final CloudinaryService _storageService = CloudinaryService();
  final TextEditingController _nameController = TextEditingController();

  File? _pickedImage;
  bool _isSaving = false;
  bool get _isEditing => widget.category != null;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.category!.name;
      _existingImageUrl = widget.category!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
    if (mounted) Navigator.pop(context); // close bottom sheet
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const MyText(text: 'Select Image Source', fontSize: 18, fontWeight: FontWeight.bold),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: Colors.blue,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _sourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: Colors.green,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  if (_pickedImage != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                    _sourceButton(
                      icon: Icons.delete_rounded,
                      label: 'Remove',
                      color: Colors.red,
                      onTap: () {
                        setState(() {
                          _pickedImage = null;
                          _existingImageUrl = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          MyText(text: label, color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String imageUrl = _existingImageUrl ?? "";

      // Upload new image if picked
      if (_pickedImage != null) {
        // Optional: delete old image if it exists
        if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
          await _storageService.deleteImage(_existingImageUrl!);
        }

        imageUrl = await _storageService.uploadImage(_pickedImage!, 'categories') ?? "";
      } else if (_existingImageUrl == null) {
        // Image was removed by user
        imageUrl = "";
      }

      if (_isEditing) {
        await _service.updateCategory(widget.category!.id!, _nameController.text.trim(), imageUrl);
        _showMessage('Category updated!', Colors.green);
      } else {
        await _service.createCategory(_nameController.text.trim(), imageUrl);
        _showMessage('Category created!', Colors.green);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: MyText(text: msg), backgroundColor: color));
    }
  }

  bool get _hasImage => _pickedImage != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: MyText(
          text: _isEditing ? 'Edit Category' : 'New Category',
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero image picker area ──────────────────────────────
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.05)],
                      ),
                    ),
                    child: _buildImagePreview(),
                  ),
                  // Camera icon overlay
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MyText(
                      text: 'Category Details',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 6),
                    MyText(text: 'Provide a distinct name for your category',
                        color: Colors.grey.shade600, fontSize: 14),
                    const SizedBox(height: 24),

                    // Name field
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))
                        ],
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Beverages, Main Course…',
                          prefixIcon: const Icon(Icons.category_rounded, color: primaryColor),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Category name is required' : null,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: primaryColor.withOpacity(0.5),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(_isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded),
                        label: MyText(
                          text: _isEditing ? 'Update Category' : 'Create Category',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!, fit: BoxFit.cover, width: double.infinity, height: 240);
    }
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 240,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded, size: 64, color: primaryColor.withOpacity(0.6)),
          const SizedBox(height: 12),
          MyText(
            text: 'Tap to add category image',
            color: primaryColor.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          const SizedBox(height: 6),
          MyText(text: 'Upload high quality image for better display',
              color: Colors.grey.shade600, fontSize: 13),
        ],
      ),
    );
  }
}
