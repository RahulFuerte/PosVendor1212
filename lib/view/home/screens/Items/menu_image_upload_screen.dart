import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos/data/services/menu_image_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/home/navigation.dart';

class MenuImageUploadScreen extends StatefulWidget {
  const MenuImageUploadScreen({super.key});

  @override
  State<MenuImageUploadScreen> createState() => _MenuImageUploadScreenState();
}

class _MenuImageUploadScreenState extends State<MenuImageUploadScreen> {
  final MenuImageService _menuImageService = MenuImageService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      SnackBarUtils.showError(context, 'Error picking image: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);

    try {
      final success = await _menuImageService.uploadMenuImage(_selectedImage!);
      if (success) {
        SnackBarUtils.showSuccess(context, 'Menu updated successfully!');
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pop(context, true);
          });
        }
      }
    } catch (e) {
      SnackBarUtils.showError(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FA),
      appBar: AppBar(
        title: const MyText(text: "Upload Menu Image", fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildImagePreview(),
              const SizedBox(height: 40),
              if (_isUploading) _buildLoadingIndicator() else _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(_selectedImage!, fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                MyText(
                  text: "No image selected",
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const CircularProgressIndicator(color: appbar1, strokeWidth: 3),
        const SizedBox(height: 20),
        const MyText(
          text: "Uploading your menu...",
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        const SizedBox(height: 8),
        MyText(
          text: "This might take a moment",
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: const MyText(text: "Select From Gallery"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              side: BorderSide(color: Colors.grey.shade300),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedImage != null)
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const MyText(text: "Upload Menu Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: appbar1,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }
}
