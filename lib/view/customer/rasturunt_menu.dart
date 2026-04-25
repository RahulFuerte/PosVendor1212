import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/category_model.dart';
import 'package:pos/data/models/product_model.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/view/home/widgets/bill_cart_widget.dart';
import 'package:pos/view/home/widgets/show_save_order_bottom_sheet.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/customer/customer_order_summary.dart';
import 'package:pos/view/customer/cart_screen.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RasturuntMenu extends StatefulWidget {
  final String adminId;
  final String userPhone;
  final String restaurantName;
  final String? restaurantImage;
  final String? restaurantLocation;

  const RasturuntMenu({
    super.key,
    required this.adminId,
    required this.userPhone,
    required this.restaurantName,
    this.restaurantImage,
    this.restaurantLocation,
  });

  @override
  State<RasturuntMenu> createState() => _RasturuntMenuState();
}

class _RasturuntMenuState extends State<RasturuntMenu> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  List<Map<String, dynamic>> _menuItems = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _loadCustomerInfo();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        CategoryService().getPublicCategories(widget.adminId),
        ProductService().getPublicProducts(widget.adminId),
      ]);

      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _menuItems = (results[1] as List<ProductModel>).map((p) => p.toJson()).toList();
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Initial load failed: $e', name: 'RasturuntMenu');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('name') ?? '';
    _mobileController.text = prefs.getString('phoneNumber') ?? widget.userPhone;
  }

  Future<void> _fetchMenu() async {
    setState(() => _isLoading = true);
    try {
      final products = await ProductService().getPublicProducts(
        widget.adminId,
        categoryId: _selectedCategoryId,
      );
      setState(() {
        _menuItems = products.map((p) => p.toJson()).toList().cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Menu fetch failed: $e', name: 'RasturuntMenu');
      setState(() => _isLoading = false);
    }
  }

  void _syncCart(List<Map<String, dynamic>> items) {
    final total = items.fold<double>(
        0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));
    Provider.of<PrintProvider>(context, listen: false).additem(items, total);
  }

  void _addToCart(String id, String name, String price, int quantity, String unit, num unitQty,
      List<Map<String, dynamic>> addonList) {
    final parsedPrice = double.tryParse(price) ?? 0.0;
    final displayName = unit.isNotEmpty ? '$name ($unitQty $unit)' : name;
    final provider = Provider.of<PrintProvider>(context, listen: false);
    final currentCart = List<Map<String, dynamic>>.from(provider.posts);
    final existingIndex = currentCart.indexWhere((item) => item['productId'] == id && item['name'] == displayName);

    if (existingIndex != -1) {
      currentCart[existingIndex]['quantity'] += quantity;
      currentCart[existingIndex]['addons'] = addonList;
    } else {
      currentCart.add({
        'productId': id,
        'name': displayName,
        'price': parsedPrice,
        'quantity': quantity,
        'unit': unit,
        'addons': addonList,
      });
    }

    _syncCart(currentCart);

    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    if (tableProvider.selectedTableId != null) {
      tableProvider.setTableCart(tableProvider.selectedTableId!, currentCart);
    }
  }

  void _removeFromCart(String name) {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final items = List<Map<String, dynamic>>.from(printProvider.posts);
    final existingIndex = items.indexWhere((i) => i['name'] == name);

    if (existingIndex != -1) {
      if (items[existingIndex]['quantity'] > 1) {
        items[existingIndex]['quantity']--;
      } else {
        items.removeAt(existingIndex);
      }
      _syncCart(items);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter items based on search query AND Veg/Non-Veg toggle
    final filteredItems = _menuItems.where((item) {
      final matchesSearch = item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            _buildSearchBar(),
            _buildCategorySelector(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingList()
                  : filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: filteredItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 20, color: Colors.black12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _ZomatoMenuItem(
                              item: item,
                              onAdd: _addToCart,
                              onRemove: _removeFromCart,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          _iconButton(Icons.arrow_back_ios_new, () => Navigator.of(context).pop()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(text: widget.restaurantName, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    MyText(text: widget.restaurantLocation ?? 'Nearby', fontSize: 12, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          Consumer<PrintProvider>(
            builder: (context, cart, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _iconButton(Icons.shopping_cart_outlined, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CartScreen(adminId: widget.adminId)),
                    );
                  }),
                  if (cart.posts.isNotEmpty)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: MyText(
                            text: '${cart.posts.length}',
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Search for dish names',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 54,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : _categories[index - 1];
          final isSelected = isAll ? _selectedCategoryId == null : _selectedCategoryId == category?.id;

          return _categoryChip(
            label: isAll ? 'All Menu' : category!.name,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedCategoryId = isAll ? null : category?.id;
              });
              _fetchMenu();
            },
          );
        },
      ),
    );
  }

  Widget _categoryChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200),
          boxShadow: isSelected
              ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Center(
          child: MyText(
            text: label,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const MyText(text: 'No dishes found', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 32),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 20, width: 140),
                  SizedBox(height: 8),
                  SkeletonBox(height: 16, width: 80),
                  SizedBox(height: 16),
                  SkeletonBox(height: 40, width: 100),
                ],
              ),
            ),
            SizedBox(width: 16),
            SkeletonBox(height: 120, width: 120),
          ],
        ),
      ),
    );
  }
}

class _ZomatoMenuItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(String id, String name, String price, int quantity, String unit, num unitQty,
      List<Map<String, dynamic>> addonList) onAdd;
  final void Function(String name) onRemove;

  const _ZomatoMenuItem({
    required this.item,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bool isVeg = item['isVeg'] ?? true;
    final String imagePath = item['imagePath']?.toString() ?? item['imageUrl']?.toString() ?? '';
    final String name = item['name']?.toString() ?? 'Dish';
    final String price = item['price']?.toString() ?? '0';
    final String description = item['description']?.toString() ?? 'Special dish from our kitchen.';
    final String id = item['_id']?.toString() ?? item['id']?.toString() ?? '0';

    // ⚠️ IMPORTANT: _addToCart stores items as '$name ($unitQty $unit)' when unit is not empty.
    // We must compute the same displayName here so the cart lookup matches.
    final String baseVariant = item['baseVariant']?.toString() ?? '';
    final String displayName = baseVariant.isNotEmpty ? '$name (1 $baseVariant)' : name;

    // 🔥 Use Consumer here so this widget reactively rebuilds whenever cart changes
    return Consumer<PrintProvider>(
      builder: (context, cart, _) {
        final cartItem = cart.posts.firstWhere(
          (i) => i['name'] == displayName,
          orElse: () => {},
        );
        final int quantity = (cartItem['quantity'] ?? 0).toInt();

        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Veg icon
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(color: isVeg ? Colors.green : Colors.red, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.circle, color: isVeg ? Colors.green : Colors.red, size: 8),
                      ),
                      const SizedBox(height: 8),
                      MyText(text: name, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      const SizedBox(height: 4),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: MyText(
                            text: description,
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            maxLines: 3,
                          ),
                        ),
                      MyText(text: '₹$price', fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // RIGHT: Image + ADD button
                Container(
                  width: 130,
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // 1. IMAGE BOX
                      Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedBlobImage(
                            imageUrl: imagePath,
                            tableName: 'food_items',
                            recordId: id,
                            width: 124,
                            height: 124,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              width: 124,
                              height: 124,
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
                            ),
                          ),
                        ),
                      ),
                      // 2. FLOATING BUTTON
                      Positioned(
                        bottom: -12,
                        child: quantity > 0
                            ? Container(
                                width: 100,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: InkWell(
                                        onTap: () => onRemove(displayName),
                                        child: Container(
                                          color: Colors.transparent,
                                          child: const Icon(Icons.remove, color: primaryColor, size: 24),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: MyText(
                                          text: '$quantity',
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: InkWell(
                                        onTap: () => onAdd(id, name, price, 1, item['baseVariant'] ?? '', 1, []),
                                        child: Container(
                                          color: Colors.transparent,
                                          child: const Icon(Icons.add, color: primaryColor, size: 24),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : InkWell(
                                onTap: () {
                                  onAdd(id, name, price, 1, item['baseVariant'] ?? '', 1, []);
                                  SnackBarUtils.showInfo(context, 'Added $name to cart');
                                },
                                child: Container(
                                  width: 100,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5)),
                                    ],
                                  ),
                                  child: const Center(
                                    child: MyText(
                                      text: 'ADD',
                                      color: primaryColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ));
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double height;
  final double width;

  const SkeletonBox({required this.height, required this.width, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
    );
  }
}
