// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:image_picker/image_picker.dart';

// Project imports:
import 'package:pos/data/models/category_model.dart';
import 'package:pos/data/models/product_model.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/data/services/cloudinary_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class AddItemScreen extends StatefulWidget {
  final ProductModel? product; // null = create, non-null = edit
  const AddItemScreen({this.product, super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  // ── Services ──────────────────────────────────────────────
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final CloudinaryService _storageService = CloudinaryService();

  // ── State ─────────────────────────────────────────────────
  bool isLoading = true;
  bool isUploading = false;
  String priceType = 'Fixed';
  String baseVarient = 'Kg';
  String selectedVariantUnit = 'Kg';
  bool enableVariants = false;
  bool enableAddons = false;
  List<Map<String, dynamic>> variants = [];
  List<Map<String, dynamic>> addons = [];
  String? selectedSize;
  File? selectedImage;
  String? existingImageUrl;
  List<CategoryModel> categories = [];
  String? selectedCategoryId;

  final List<String> baseVarients = ['Kg', 'Liter', 'Item Per Pc'];
  final List<String> sizeOptions = ['Small', 'Medium', 'Large', 'Extra Large'];

  // ── Controllers ───────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final foodNameController = TextEditingController();
  final foodPriceController = TextEditingController();
  final foodPrice2Controller = TextEditingController();
  final foodPrice3Controller = TextEditingController();
  final foodCodeController = TextEditingController();
  final foodStockController = TextEditingController();
  final foodDescriptionController = TextEditingController();
  final variantQtyController = TextEditingController();
  final variantPriceController = TextEditingController();
  final addonNameController = TextEditingController();
  final addonPriceController = TextEditingController();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    foodNameController.dispose();
    foodPriceController.dispose();
    foodPrice2Controller.dispose();
    foodPrice3Controller.dispose();
    foodCodeController.dispose();
    foodStockController.dispose();
    foodDescriptionController.dispose();
    variantQtyController.dispose();
    variantPriceController.dispose();
    addonNameController.dispose();
    addonPriceController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      try {
        categories = await _categoryService.getCategories();
      } catch (_) {}

      if (_isEditing) {
        final p = widget.product!;
        foodNameController.text = p.name;
        foodPriceController.text = p.price.toStringAsFixed(0);
        foodPrice2Controller.text = p.price2?.toStringAsFixed(0) ?? '';
        foodPrice3Controller.text = p.price3?.toStringAsFixed(0) ?? '';
        foodCodeController.text = p.foodCode ?? '';
        foodStockController.text = p.stocks?.toString() ?? '';
        foodDescriptionController.text = p.description ?? '';
        existingImageUrl = p.imagePath;

        // Robust handling for Dropdown values to avoid "value not found in items" errors
        final pType = p.priceType;
        if (pType != null && pType.isNotEmpty && (pType == 'Fixed' || pType == 'Open')) {
          priceType = pType;
        } else {
          priceType = 'Fixed';
        }

        final bVariant = p.baseVariant;
        if (bVariant != null && bVariant.isNotEmpty && baseVarients.contains(bVariant)) {
          baseVarient = bVariant;
        } else {
          baseVarient = 'Kg';
        }

        selectedCategoryId = p.categoryId.isEmpty ? null : p.categoryId;
        // Ensure selectedCategoryId exists in categories list to avoid dropdown error
        if (selectedCategoryId != null && !categories.any((c) => c.id == selectedCategoryId)) {
          selectedCategoryId = null;
        }

        if (p.variants != null) {
          variants = List<Map<String, dynamic>>.from(p.variants!.map((v) => Map<String, dynamic>.from(v as Map)));
        }
        if (p.addons != null) {
          addons = List<Map<String, dynamic>>.from(p.addons!.map((a) => Map<String, dynamic>.from(a as Map)));
          enableAddons = addons.isNotEmpty;
        }
        enableVariants = variants.isNotEmpty;
      }
      // Default category
      if (selectedCategoryId == null && categories.isNotEmpty) {
        selectedCategoryId = categories.first.id;
      }
    } catch (e) {
      debugPrint("Error initializing data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Image picker ──────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null && mounted) setState(() => selectedImage = File(picked.path));
    if (mounted) Navigator.pop(context);
  }

  void _showImageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const MyText(text: 'Product Image', fontSize: 18, fontWeight: FontWeight.bold),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imgBtn(Icons.photo_library_rounded, 'Gallery', Colors.blue, () => _pickImage(ImageSource.gallery)),
                  _imgBtn(Icons.camera_alt_rounded, 'Camera', Colors.green, () => _pickImage(ImageSource.camera)),
                  if (selectedImage != null || (existingImageUrl != null && existingImageUrl!.isNotEmpty))
                    _imgBtn(Icons.delete_rounded, 'Remove', Colors.red, () {
                      setState(() {
                        selectedImage = null;
                        existingImageUrl = null;
                      });
                      Navigator.pop(context);
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgBtn(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3))),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          MyText(text: label, color: color, fontWeight: FontWeight.w600, fontSize: 12),
        ]),
      );

  // ── Submit ────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategoryId == null) {
      SnackBarUtils.showWarning(context, 'Please select a category');
      return;
    }
    setState(() => isUploading = true);
    try {
      final name = foodNameController.text.trim();
      final price = double.tryParse(foodPriceController.text.trim()) ?? 0;
      final price2 = double.tryParse(foodPrice2Controller.text.trim()) ?? 0.0;
      final price3 = double.tryParse(foodPrice3Controller.text.trim()) ?? 0.0;
      final code = foodCodeController.text.trim().isEmpty ? "" : foodCodeController.text.trim();
      final stocks = int.tryParse(foodStockController.text.trim()) ?? 0;
      final desc = foodDescriptionController.text.trim().isEmpty ? "" : foodDescriptionController.text.trim();

      String imageUrl = existingImageUrl ?? "";
      if (selectedImage != null) {
        // Optional: delete old image if it exists
        if (existingImageUrl != null && existingImageUrl!.isNotEmpty) {
          await _storageService.deleteImage(existingImageUrl!);
        }

        imageUrl = await _storageService.uploadImage(selectedImage!, 'products') ?? "";
      } else if (existingImageUrl == null) {
        // Image was removed by user
        imageUrl = "";
      }

      final formattedVariants = variants
          .map((v) => {
                'qty': v['qty'],
                'unit': v['unitType'] ?? v['unit'] ?? '',
                'price': v['price'],
                'size': v['size'] ?? '',
              })
          .toList();

      if (_isEditing) {
        await _productService.updateProduct(widget.product!.id!, {
          'name': name,
          'price': priceType == 'Open' ? 0 : price,
          'price2': priceType == 'Open' ? 0 : price2,
          'price3': priceType == 'Open' ? 0 : price3,
          'priceType': priceType,
          'categoryId': selectedCategoryId,
          'foodCode': code,
          'stocks': stocks,
          'description': desc,
          'baseVariant': baseVarient,
          'variants': formattedVariants,
          'addons': addons,
          'imageUrl': imageUrl,
          'image_url': imageUrl, // Backend fallback
          'imagePath': imageUrl, // Backend fallback
        });
        SnackBarUtils.showSuccess(context, 'Product updated!');
      } else {
        await _productService.createProduct(
          name: name,
          price: priceType == 'Open' ? 0 : price,
          categoryId: selectedCategoryId!,
          description: desc,
          foodCode: code,
          price2: priceType == 'Open' ? 0 : price2,
          price3: priceType == 'Open' ? 0 : price3,
          stocks: stocks,
          imageUrl: imageUrl,
          image_url: imageUrl, // Backend fallback
          imagePath: imageUrl, // Ensure compatibility
          priceType: priceType,
          baseVariant: baseVarient,
          variants: formattedVariants,
          addons: addons,
        );
        SnackBarUtils.showSuccess(context, 'Product added!');
        _clearForm();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      SnackBarUtils.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _clearForm() {
    foodNameController.clear();
    foodPriceController.clear();
    foodPrice2Controller.clear();
    foodPrice3Controller.clear();
    foodCodeController.clear();
    foodStockController.clear();
    foodDescriptionController.clear();
    variantQtyController.clear();
    variantPriceController.clear();
    setState(() {
      variants.clear();
      addons.clear();
      enableVariants = false;
      enableAddons = false;
      priceType = 'Fixed';
      selectedImage = null;
    });
  }


  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: MyText(
          text: _isEditing ? 'Edit Product' : 'Add New Product',
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildImagePicker(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBasicInfo(),
                          const SizedBox(height: 20),
                          _buildPricingSection(),
                          const SizedBox(height: 20),
                          _buildVariantsSection(),
                          const SizedBox(height: 20),
                          _buildAddonsSection(),
                          const SizedBox(height: 20),
                          _buildInventorySection(),
                          const SizedBox(height: 32),
                          _buildSubmitButton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Image Picker Hero ──────────────────────────────────────
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageSheet,
      child: Stack(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _buildImageContent(),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const MyText(text: 'Change Photo', color: primaryColor, fontWeight: FontWeight.w700, fontSize: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns true only for reachable-looking http/https URLs.
  /// Rejects empty strings, example.com placeholders, and non-http schemes.
  static bool _isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) return false;
    // Reject known placeholder domains
    final host = uri.host.toLowerCase();
    if (host == 'example.com' || host == 'example.org' || host == 'placeholder.com') return false;
    return true;
  }

  Widget _buildImageContent() {
    if (selectedImage != null) {
      return Image.file(
        selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 240,
      );
    }
    if (_isValidImageUrl(existingImageUrl)) {
      return Image.network(
        existingImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 240,
        cacheWidth: 800, // cap decoded size → prevents memory spike
        errorBuilder: (_, __, ___) => _imgPlaceholder(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              color: primaryColor,
              strokeWidth: 2,
            ),
          );
        },
      );
    }
    return _imgPlaceholder();
  }

  Widget _imgPlaceholder() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_photo_alternate_rounded, size: 64, color: primaryColor.withOpacity(0.6)),
          const SizedBox(height: 12),
          MyText(
              text: 'Tap to add product image',
              color: primaryColor.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 16),
          const SizedBox(height: 6),
          MyText(text: 'Gallery or Camera', color: Colors.grey.shade600, fontSize: 13),
        ]),
      );

  // ── Section Card builder ───────────────────────────────────
  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              MyText(text: title, fontSize: 17, fontWeight: FontWeight.bold),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child),
        ],
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────
  Widget _buildBasicInfo() => _sectionCard(
        title: 'Basic Information',
        icon: Icons.info_outline_rounded,
        child: Column(children: [
          // Category
          DropdownButtonFormField<String>(
            value: selectedCategoryId,
            decoration: _dec('Category', Icons.category_rounded),
            items: categories.map((c) => DropdownMenuItem(value: c.id, child: MyText(text: c.name))).toList(),
            onChanged: (v) => setState(() => selectedCategoryId = v),
            validator: (v) => v == null ? 'Category required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: foodNameController,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Product Name *', Icons.shopping_bag_rounded),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: foodCodeController,
            decoration: _dec('Item Code / PLU', Icons.qr_code_rounded),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Base Unit
          DropdownButtonFormField<String>(
            value: baseVarient,
            decoration: _dec('Item Unit', Icons.scale_rounded),
            items: baseVarients.map((u) => DropdownMenuItem(value: u, child: MyText(text: u))).toList(),
            onChanged: (v) => setState(() => baseVarient = v ?? 'Kg'),
          ),
        ]),
      );

  Widget _buildPricingSection() => _sectionCard(
        title: 'Pricing',
        icon: Icons.currency_rupee_rounded,
        child: Column(children: [
          // Price type toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: ['Fixed', 'Open'].map((type) {
                final isSel = priceType == type;
                return Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() {
                    priceType = type;
                    if (type == 'Open') {
                      foodPriceController.text = '0';
                      foodPrice2Controller.text = '0';
                      foodPrice3Controller.text = '0';
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: MyText(
                        text: type,
                        color: isSel ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ));
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: foodPriceController,
            keyboardType: TextInputType.number,
            readOnly: priceType == 'Open',
            decoration: _dec('Price 1 (₹) *', Icons.currency_rupee_rounded),
            validator: (v) =>
                v == null || v.trim().isEmpty || double.tryParse(v.trim()) == null ? 'Valid price required' : null,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: foodPrice2Controller,
                    keyboardType: TextInputType.number,
                    readOnly: priceType == 'Open',
                    decoration: _dec('Price 2 (₹)', Icons.currency_rupee))),
            const SizedBox(width: 16),
            Expanded(
                child: TextFormField(
                    controller: foodPrice3Controller,
                    keyboardType: TextInputType.number,
                    readOnly: priceType == 'Open',
                    decoration: _dec('Price 3 (₹)', Icons.currency_rupee))),
          ]),
        ]),
      );

  Widget _buildVariantsSection() => _sectionCard(
        title: 'Variants',
        icon: Icons.tune_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const MyText(text: 'Enable Variants', fontWeight: FontWeight.w700, fontSize: 16),
            subtitle:
                MyText(text: 'Different sizes, weights, or quantities', fontSize: 13, color: Colors.grey.shade600),
            value: enableVariants,
            activeColor: primaryColor,
            onChanged: (v) => setState(() {
              enableVariants = v;
              if (!v) {
                variants.clear();
                variantQtyController.clear();
                variantPriceController.clear();
                selectedSize = null;
              }
            }),
          ),
          if (enableVariants) ...[
            Divider(color: Colors.grey.shade200, height: 24),
            DropdownButtonFormField<String>(
              value: selectedVariantUnit,
              decoration: _dec('Variant Unit', Icons.scale_rounded),
              items: ['Kg', 'Gm', 'Ml', 'Liter', 'Item Per Pc', 'Size']
                  .map((e) => DropdownMenuItem(value: e, child: MyText(text: e)))
                  .toList(),
              onChanged: (v) => setState(() {
                selectedVariantUnit = v!;
                selectedSize = null;
                variantQtyController.clear();
              }),
            ),
            const SizedBox(height: 16),
            if (selectedVariantUnit == 'Size') ...[
              DropdownButtonFormField<String>(
                value: selectedSize,
                hint: const MyText(text: 'Select size'),
                decoration: _dec('Size', Icons.straighten_rounded),
                items: sizeOptions.map((e) => DropdownMenuItem(value: e, child: MyText(text: e))).toList(),
                onChanged: (v) => setState(() => selectedSize = v),
              ),
              const SizedBox(height: 16),
            ],
            if (selectedVariantUnit != 'Size') ...[
              TextFormField(
                  controller: variantQtyController,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Quantity', Icons.numbers_rounded)),
              const SizedBox(height: 16),
            ],
            TextFormField(
                controller: variantPriceController,
                keyboardType: TextInputType.number,
                decoration: _dec('Variant Price (₹)', Icons.currency_rupee_rounded)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (variantPriceController.text.isEmpty) return;
                  if (selectedVariantUnit == 'Size' && selectedSize == null) return;
                  setState(() {
                    variants.add({
                      'unitType': selectedVariantUnit,
                      'size': selectedVariantUnit == 'Size' ? selectedSize : null,
                      'qty': selectedVariantUnit == 'Size' ? 1 : double.tryParse(variantQtyController.text) ?? 0,
                      'price': double.tryParse(variantPriceController.text) ?? 0,
                    });
                    variantQtyController.clear();
                    variantPriceController.clear();
                    selectedSize = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.add_rounded),
                label: const MyText(text: 'Add Variant', fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (variants.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: variants.length,
                  itemBuilder: (_, i) {
                    final v = variants[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.tune_rounded, size: 18, color: primaryColor)),
                      title: MyText(
                          text: v['unitType'] == 'Size' ? '${v['size']}' : '${v['qty']} ${v['unitType']}',
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        MyText(text: '₹${v['price']}', fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                        const SizedBox(width: 8),
                        IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.red),
                            onPressed: () => setState(() => variants.removeAt(i))),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ],
        ]),
      );

  Widget _buildAddonsSection() => _sectionCard(
        title: 'Add-Ons',
        icon: Icons.add_circle_outline_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const MyText(text: 'Enable Add-Ons', fontWeight: FontWeight.w700, fontSize: 16),
            subtitle: MyText(text: 'Extras customers can choose', fontSize: 13, color: Colors.grey.shade600),
            value: enableAddons,
            activeColor: primaryColor,
            onChanged: (v) => setState(() {
              enableAddons = v;
              if (!v) addons.clear();
            }),
          ),
          if (enableAddons) ...[
            Divider(color: Colors.grey.shade200, height: 24),
            TextFormField(
                controller: addonNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Add-On Name', Icons.label_outline_rounded)),
            const SizedBox(height: 16),
            TextFormField(
                controller: addonPriceController,
                keyboardType: TextInputType.number,
                decoration: _dec('Add-On Price (₹)', Icons.currency_rupee_rounded)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (addonNameController.text.isEmpty || addonPriceController.text.isEmpty) return;
                  setState(() {
                    addons.add({
                      'name': addonNameController.text.trim(),
                      'price': double.tryParse(addonPriceController.text) ?? 0
                    });
                    addonNameController.clear();
                    addonPriceController.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.add_rounded),
                label: const MyText(text: 'Add Add-On', fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (addons.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: addons.length,
                  itemBuilder: (_, i) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        child: const Icon(Icons.add_rounded, size: 18, color: Colors.orange)),
                    title: MyText(text: addons[i]['name'] ?? '', fontWeight: FontWeight.w700, fontSize: 15),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      MyText(
                          text: '₹${addons[i]['price']}',
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 15),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Colors.red),
                          onPressed: () => setState(() => addons.removeAt(i))),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        ]),
      );

  Widget _buildInventorySection() => _sectionCard(
        title: 'Inventory & Details',
        icon: Icons.inventory_2_outlined,
        child: Column(children: [
          TextFormField(
              controller: foodStockController,
              keyboardType: TextInputType.number,
              decoration: _dec('Stock Quantity', Icons.inventory_2_outlined)),
          const SizedBox(height: 16),
          TextFormField(
              controller: foodDescriptionController,
              maxLines: 3,
              decoration: _dec('Description (optional)', Icons.description_outlined)),
        ]),
      );

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: isUploading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: primaryColor.withOpacity(0.5),
          ),
          icon: isUploading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded),
          label: MyText(
            text: _isEditing ? 'Update Product' : 'Add Product',
            fontSize: 17,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      );
}
