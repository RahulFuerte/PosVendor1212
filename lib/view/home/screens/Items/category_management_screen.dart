import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/category_model.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/view/home/screens/Items/category_form_screen.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

// Avatar accent colours – one per category card
const _kAvatarColors = [
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
  Color(0xFF795548),
  Color(0xFF607D8B),
];

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final CategoryService _service = CategoryService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ────────────────────────────────────────────────────────────
  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _service.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      SnackBarUtils.showError(context, 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _openForm({CategoryModel? category}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CategoryFormScreen(category: category)),
    );
    if (result == true) _loadCategories();
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const MyText(text: 'Delete Category', fontWeight: FontWeight.bold),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: MyText(
                text: 'Delete "${cat.name}"?\nProducts in this category may be affected.',
                fontSize: 13.5,
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: MyText(text: 'Cancel', color: Colors.grey.shade600),
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
      await _service.deleteCategory(cat.id!);
      SnackBarUtils.showSuccess(context, 'Category deleted');
      _loadCategories();
    } catch (e) {
      SnackBarUtils.showError(context, 'Error: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  List<CategoryModel> get _filtered {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Color _accentColor(int i) => _kAvatarColors[i % _kAvatarColors.length];

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
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
        label: const MyText(
          text: 'Add Category',
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Categories',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          MyText(
            text: '${_categories.length} total',
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: _loadCategories,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Search Bar ───────────────────────────────────────────────────────────────
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
            hintText: 'Search categories…',
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

  // ── Summary Row ──────────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    final count = _filtered.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          MyText(
            text: _searchQuery.isEmpty
                ? '$count ${count == 1 ? 'category' : 'categories'}'
                : '$count result${count == 1 ? '' : 's'}',
            color: Colors.grey.shade500,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────────
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
      itemBuilder: (_, i) => _buildCard(list[i], i),
    );
  }

  // ── Category Card ─────────────────────────────────────────────────────────────
  Widget _buildCard(CategoryModel cat, int index) {
    final color = _accentColor(index);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openForm(category: cat),
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
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              const SizedBox(width: 14),
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          cat.imageUrl!,
                          fit: BoxFit.cover,
                          width: 46,
                          height: 46,
                          errorBuilder: (_, __, ___) => Icon(Icons.category_rounded, color: color, size: 24),
                        ),
                      )
                    : Icon(Icons.category_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              // Name + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MyText(
                      text: cat.name,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: 0.1,
                    ),
                    if (cat.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        MyText(
                          text: '${cat.createdAt!.day}/${cat.createdAt!.month}/${cat.createdAt!.year}',
                          color: Colors.grey.shade400,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _actionBtn(Icons.edit_rounded, primaryColor, () => _openForm(category: cat)),
                  const SizedBox(width: 8),
                  _actionBtn(Icons.delete_outline_rounded, Colors.red.shade400, () => _deleteCategory(cat)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final isSearch = _searchQuery.isNotEmpty;
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
                isSearch ? Icons.search_off_rounded : Icons.category_rounded,
                size: 56,
                color: primaryColor.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 20),
            MyText(
              text: isSearch ? 'No Results Found' : 'No Categories Yet',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
            const SizedBox(height: 8),
            MyText(
              text: isSearch ? 'Try a different search term' : 'Create your first category to start organising your menu',
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
                label: const MyText(
                  text: 'Add First Category',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
