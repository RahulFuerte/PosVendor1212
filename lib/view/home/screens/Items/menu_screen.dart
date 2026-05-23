import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/data/models/product_model.dart';
import 'package:pos/data/models/category_model.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/view/home/screens/Items/addItemScreen.dart';
import 'package:pos/view/home/screens/Items/category_form_screen.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/home/screens/Items/menu_image_upload_screen.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedTab = 0; // 0: Products, 1: Categories
  bool isLoading = true;

  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ProductModel> products = [];
  List<CategoryModel> categories = [];
  List<ProductModel> filteredProducts = [];
  List<CategoryModel> filteredCategories = [];

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      final canViewProducts = subProvider.hasPermission("Product", checkView: true);
      final canViewCategories = subProvider.hasPermission("Category", checkView: true);

      if (!canViewProducts && !canViewCategories) {
        setState(() {
          products = [];
          categories = [];
          isLoading = false;
        });
        return;
      }

      final futures = <Future<dynamic>>[];
      if (canViewProducts) {
        futures.add(_productService.getProducts());
      } else {
        futures.add(Future.value(<ProductModel>[]));
      }

      if (canViewCategories) {
        futures.add(_categoryService.getCategories());
      } else {
        futures.add(Future.value(<CategoryModel>[]));
      }

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          products = results[0] as List<ProductModel>;
          categories = results[1] as List<CategoryModel>;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('MenuScreen load error: $e');
      SnackBarUtils.showError(context, 'Failed to load menu: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    final q = searchQuery.toLowerCase();
    if (selectedTab == 0) {
      filteredProducts = products.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else {
      filteredCategories = categories.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
      _applyFilters();
    });
  }

  Future<void> _deleteProduct(ProductModel p) async {
    final ok = await _showDeleteConfirm('Delete Product', 'Delete "${p.name}"?');
    if (ok != true) return;
    try {
      await _productService.deleteProduct(p.id!);
      SnackBarUtils.showSuccess(context, 'Product deleted');
      _loadData();
    } catch (e) {
      SnackBarUtils.showError(context, 'Error: $e');
    }
  }

  Future<void> _deleteCategory(CategoryModel c) async {
    final ok =
        await _showDeleteConfirm('Delete Category', 'Delete "${c.name}"?\nProducts in this category may be affected.');
    if (ok != true) return;
    try {
      await _categoryService.deleteCategory(c.id!);
      SnackBarUtils.showSuccess(context, 'Category deleted');
      _loadData();
    } catch (e) {
      SnackBarUtils.showError(context, 'Error: $e');
    }
  }

  Future<bool?> _showDeleteConfirm(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: MyText(text: title, fontWeight: FontWeight.bold),
        content: MyText(text: content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const MyText(text: 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const MyText(text: 'Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: MyText(text: AppLocale.menuManagement.getString(context), fontSize: 17, color: Colors.black, fontWeight: FontWeight.w600),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          Consumer<SubscriptionProvider>(
            builder: (context, subProvider, _) {
              if (!subProvider.hasPermission("Product", checkCreate: true)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.cloud_upload_outlined),
                tooltip: 'Upload Menu Image',
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MenuImageUploadScreen()),
                  );
                  if (res == true) _loadData();
                },
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: appbar1))
          : Consumer<SubscriptionProvider>(
              builder: (context, subProvider, _) {
                final featureKey = selectedTab == 0 ? "Product" : "Category";
                final hasView = subProvider.hasPermission(featureKey, checkView: true);

                if (!hasView) {
                  return AccessDeniedWidget(feature: featureKey);
                }

                return Column(
                  children: [
                    _buildTabSwitcher(),
                    _buildSearchBar(),
                    _buildSummaryRow(),
                    Expanded(child: _buildList()),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
      floatingActionButton: Consumer<SubscriptionProvider>(
        builder: (context, subProvider, _) {
          final featureKey = selectedTab == 0 ? "Product" : "Category";
          if (!subProvider.hasPermission(featureKey, checkCreate: true)) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () async {
              if (selectedTab == 0) {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemScreen()));
                if (res == true) _loadData();
              } else {
                final res =
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryFormScreen()));
                if (res == true) _loadData();
              }
            },
            backgroundColor: appbar1,
            icon: const Icon(Icons.add, color: Colors.white),
            label: MyText(
              text: selectedTab == 0 ? "Add Product" : "Add Category",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 45,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(25)),
        child: Row(
          children: [
            _tabButton("Products", 0),
            _tabButton("Categories", 1),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          selectedTab = index;
          searchQuery = '';
          _searchCtrl.clear();
          _applyFilters();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? appbar1 : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: MyText(
            text: text,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: selectedTab == 0 ? "Search products..." : "Search categories...",
          prefixIcon: Icon(Icons.search, color: appbar1),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: appbar1)),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final count = selectedTab == 0 ? filteredProducts.length : filteredCategories.length;
    final label = selectedTab == 0 ? "product" : "category";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MyText(
          text: "$count $label${count == 1 ? '' : (selectedTab == 0 ? 's' : 'ies')}",
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (selectedTab == 0) {
      if (filteredProducts.isEmpty) return const Center(child: MyText(text: "No products found"));
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: filteredProducts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildProductCard(filteredProducts[i]),
      );
    } else {
      if (filteredCategories.isEmpty) return const Center(child: MyText(text: "No categories found"));
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: filteredCategories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCategoryCard(filteredCategories[i]),
      );
    }
  }

  Widget _buildProductCard(ProductModel p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: p.imagePath != null && p.imagePath!.isNotEmpty
                  ? Image.network(p.imagePath!,
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: grey))
                  : const Icon(Icons.fastfood, color: grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(text: p.name, fontWeight: FontWeight.bold, fontSize: 15),
                const SizedBox(height: 4),
                MyText(text: "₹${p.price.toStringAsFixed(2)}", color: appbar1, fontWeight: FontWeight.w600),
              ],
            ),
          ),
          Consumer<SubscriptionProvider>(
            builder: (context, subProvider, _) {
              final canEdit = subProvider.hasPermission("Product", checkEdit: true);
              final canDelete = subProvider.hasPermission("Product", checkDelete: true);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () async {
                        final res =
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen(product: p)));
                        if (res == true) _loadData();
                      },
                    ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _deleteProduct(p),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: appbar1.withOpacity(0.1),
            child: MyText(
              text: c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
              color: appbar1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: MyText(text: c.name, fontWeight: FontWeight.bold, fontSize: 15)),
          Consumer<SubscriptionProvider>(
            builder: (context, subProvider, _) {
              final canEdit = subProvider.hasPermission("Category", checkEdit: true);
              final canDelete = subProvider.hasPermission("Category", checkDelete: true);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () async {
                        final res = await Navigator.push(
                            context, MaterialPageRoute(builder: (_) => CategoryFormScreen(category: c)));
                        if (res == true) _loadData();
                      },
                    ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _deleteCategory(c),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
