import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/product_model.dart';
import 'package:pos/data/models/category_model.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/view/home/screens/Items/addItemScreen.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

// Accent colours for product card left bar
const _kAccentColors = [
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
  Color(0xFF795548),
  Color(0xFF607D8B),
];

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
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

  // ── Data ─────────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _productService.getProducts(),
        _categoryService.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _products = results[0] as List<ProductModel>;
          _categories = results[1] as List<CategoryModel>;
        });
      }
    } catch (e) {
      SnackBarUtils.showError(context, 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  String _getCategoryName(String? id) {
    if (id == null || id.isEmpty) return 'Uncategorized';
    try {
      return _categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _openForm({ProductModel? product}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(product: product)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteProduct(ProductModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: MyText(text: AppLocale.deleteProduct.getString(context), fontWeight: FontWeight.bold),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: MyText(
                text: AppLocale.deleteProductMsg.getString(context),
                fontSize: 13.5,
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: MyText(text: AppLocale.cancel.getString(context), color: Colors.grey.shade600),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const MyText(text: 'Delete', fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _productService.deleteProduct(p.id!);
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Product deleted');
        _loadData();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Error: $e');
    }
  }

  // ── Filtered list ─────────────────────────────────────────────────────────────
  List<ProductModel> get _filtered {
    return _products.where((p) {
      final matchSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCat = _selectedCategoryFilter == null || p.categoryId == _selectedCategoryFilter;
      return matchSearch && matchCat;
    }).toList();
  }

  Color _accentColor(int i) => _kAccentColors[i % _kAccentColors.length];

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_categories.isNotEmpty) _buildCategoryChips(),
          _buildSummaryRow(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: MyText(
          text: AppLocale.addProduct.getString(context),
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      title: MyText(
        text: AppLocale.products.getString(context),
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: AppLocale.searchProducts.getString(context),
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Category Filter Chips ─────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip('All', null),
            ..._categories.map((c) => _chip(c.name, c.id)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? catId) {
    final selected = _selectedCategoryFilter == catId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryFilter = catId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade200,
          ),
          boxShadow: selected
              ? [BoxShadow(color: primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: MyText(
          text: label,
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  // ── Summary Row ───────────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    final count = _filtered.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Row(children: [
        MyText(
          text: '$count${AppLocale.productCount.getString(context)}',
          color: Colors.grey.shade500,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5));
    }
    final list = _filtered;
    if (list.isEmpty) return _buildEmptyState();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildProductCard(list[i], i),
    );
  }

  // ── Product Card ──────────────────────────────────────────────────────────────
  Widget _buildProductCard(ProductModel p, int index) {
    final catName = _getCategoryName(p.categoryId);
    final color = _accentColor(index);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openForm(product: p),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              // Colour accent bar
              Container(
                width: 4,
                height: 82,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              // Product image / thumb
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? Image.network(
                          p.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _productThumb(color),
                        )
                      : _productThumb(color),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: p.name,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        _badge(
                          '₹${p.price.toStringAsFixed(0)}',
                          Colors.green.shade700,
                          Colors.green.shade50,
                        ),
                        const SizedBox(width: 6),
                        _badge(
                          catName,
                          primaryColor,
                          primaryColor.withOpacity(0.09),
                        ),
                      ]),
                      if ((p.foodCode != null && p.foodCode!.isNotEmpty) || p.stocks != null) ...[
                        const SizedBox(height: 5),
                        Row(children: [
                          if (p.foodCode != null && p.foodCode!.isNotEmpty)
                            MyText(
                              text: '${AppLocale.codePrefix.getString(context)}${p.foodCode}',
                              color: Colors.grey.shade400,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          if (p.foodCode != null && p.foodCode!.isNotEmpty && p.stocks != null)
                            const SizedBox(width: 10),
                          if (p.stocks != null)
                            Row(children: [
                              Icon(Icons.inventory_2_rounded, size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              MyText(
                                text: '${AppLocale.stockPrefix.getString(context)}${p.stocks}',
                                color: Colors.grey.shade400,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ]),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionBtn(Icons.edit_rounded, primaryColor, () => _openForm(product: p)),
                    const SizedBox(height: 8),
                    _actionBtn(Icons.delete_outline_rounded, Colors.red.shade400, () => _deleteProduct(p)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Rejects empty, example.com, and non-http URLs before Image.network is called.
  static bool _isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) return false;
    final host = uri.host.toLowerCase();
    if (host == 'example.com' || host == 'example.org' || host == 'placeholder.com') return false;
    return true;
  }

  Widget _productThumb(Color color) => Container(
        color: color.withOpacity(0.10),
        child: Icon(Icons.fastfood_rounded, color: color, size: 26),
      );

  Widget _badge(String label, Color textColor, Color bgColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: MyText(
          text: label,
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );

  // ── Empty State ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final isSearch = _searchQuery.isNotEmpty || _selectedCategoryFilter != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.inventory_2_rounded,
                size: 56,
                color: primaryColor.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 20),
            MyText(
              text: isSearch ? AppLocale.noProductsFound.getString(context) : AppLocale.noProductsFound.getString(context),
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
            const SizedBox(height: 8),
            MyText(
              text: isSearch ? 'Try a different search or filter' : 'Add your first product to get started',
              textAlign: TextAlign.center,
              color: Colors.grey.shade500,
              fontSize: 13.5,
            ),
            if (!isSearch) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                ),
                icon: const Icon(Icons.add_rounded),
                label: MyText(text: AppLocale.addFirstProduct.getString(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
