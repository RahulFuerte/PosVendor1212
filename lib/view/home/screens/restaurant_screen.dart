// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pos/data/services/demo_data.dart';

// Project imports:
import 'package:pos/core/network/connection_monitor.dart';
import 'package:pos/data/datasources/complete_offline_data_manager.dart';
import 'package:pos/data/datasources/data_preloading_coordinator.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/datasources/offline_bill_manager.dart';
import 'package:pos/data/services/category_service.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/view/customer/customer_order_summary.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/data/models/table_model.dart';
import 'package:pos/data/models/order_model.dart';
import '../widgets/bill_cart_widget.dart';
import '../widgets/show_save_order_bottom_sheet.dart';

class RestaurantScreen extends StatefulWidget {
  final String phoneNo;
  final bool isEditBill;
  final String? receiptNo;
  final String? role;
  const RestaurantScreen({required this.phoneNo, Key? key, this.isEditBill = false, this.receiptNo, this.role})
      : super(key: key);

  @override
  _RestaurantScreenState createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  AudioPlayer audioPlayer = AudioPlayer();
  String selectedItemName = '';
  int selectedItemPrice = 0;
  double subtotal = 0.0;
  int currentCategoryIndex = 0;
  String adminUid = '';
  String? customerId;
  bool _isDemoMode = false;
  bool _showTutorialActions = false;
  String selectedDepartment = '';
  bool isTapped = false;
  Map<String, int> itemPriceCount = {};
  double totalPrice = 0.0;
  bool isLoading = true;
  bool isContainerVisible = true;
  Future<List<Map<String, dynamic>>> foodDepartmentsFuture = Future.value([]);
  Future<List<Map<String, dynamic>>> foodItemsFuture = Future.value([]);
  List<Map<String, dynamic>> selectedItemsDetails = [];
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController userPhoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final ScrollController _gridViewController = ScrollController();
  final GlobalKey _drawerKey = GlobalKey();

  // Offline functionality
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  final DataPreloadingCoordinator _preloadingCoordinator = DataPreloadingCoordinator();
  final OfflineBillManager _offlineBillManager = OfflineBillManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  StreamSubscription<bool>? _connectionSubscription;
  bool isSearching = false;
  String search1 = '';

  TextEditingController restaurantSearch = TextEditingController();
  bool _isOnline = true;
  int _pendingBillsCount = 0;

  DateTime? currentBackPressTime;

  @override
  void initState() {
    super.initState();
    _initializeAll();
    if (widget.role == 'customer') {
      _loadCustomerInfo();
    }
    _initializeDemoTutorial();
  }

  void _initializeDemoTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isDemoMode = prefs.getBool('isDemoMode') ?? false;
    final bool isDetailedFirstTime = prefs.getBool('is_first_time_detailed_tutorial') ?? true;
    final bool isDrawerFirstTime = prefs.getBool('is_first_time_drawer_tutorial') ?? true;

    if (!mounted) return;

    setState(() {
      _isDemoMode = isDemoMode;
      _showTutorialActions = isDemoMode && (isDetailedFirstTime || isDrawerFirstTime || prefs.getBool('is_first_time_main_tutorial') != false);
    });

    // Main tutorial is now handled by Navigation when switching to restaurant tab
    // Detailed tutorial is handled by BillCartWidget after main tutorial completes
  }

  Future<void> _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userNameController.text = prefs.getString('name') ?? '';
      userPhoneController.text = prefs.getString('phoneNumber') ?? widget.phoneNo;
      customerId = prefs.getString('_id');
    });
  }

  /// Initialize all services efficiently - check connectivity first
  Future<void> _initializeAll() async {
    // Setup connection listener FIRST to know online/offline status immediately
    await _setupConnectionListenerAsync();

    // Run non-blocking initializations in parallel
    unawaited(_initializeSmartDatabase());
    unawaited(_initializeOfflineData());
    unawaited(_initializeOfflineBillManager());

    // Load data - this will use cache if offline
    foodDepartmentsFuture = fetchFoodDepartment();
    _initializeFoodItems();
  }

  /// Setup connection listener and wait for initial status
  Future<void> _setupConnectionListenerAsync() async {
    try {
      await _connectionMonitor.initialize();
      _isOnline = _connectionMonitor.isConnected;

      _connectionSubscription = _connectionMonitor.connectivityStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isOnline = isConnected;
          });
        }
        if (_isOnline) {
          _syncPendingBills();
        }
      });

    } catch (e) {
      _isOnline = false; // Assume offline on error
    }
  }

  Future<void> _initializeSmartDatabase() async {
    // Intentionally empty. Bypassing smart database service
  }

  Future<void> _initializeOfflineData() async {
    try {
      await _offlineDataManager.initialize();
      await _preloadingCoordinator.initialize();
      await _connectionMonitor.initialize();

      final adminUid = await fetchAdminUid();
      if (adminUid.isNotEmpty && !adminUid.contains('Error') && !adminUid.contains('Offline')) {
        _preloadingCoordinator.setUserPreloadingStrategy(
          adminUid,
          PreloadingStrategy(priority: PreloadingPriority.medium),
        );
        _preloadingCoordinator.triggerImmediatePreloading(adminUid);
      }
    } catch (e) {
    }
  }

  Future<void> _initializeOfflineBillManager() async {
    try {
      await _offlineBillManager.initialize();
      _updatePendingBillsCount();
    } catch (e) {
    }
  }

  Future<void> showSaveOrderBottomSheet({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController mobileController,
    required TextEditingController gstController,
    required TextEditingController addressController,
    required int itemCount,
    required double totalAmount,
    required void Function(String? customerId) onSave,
    required Color primaryColor,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SaveOrderBottomSheet(
          formKey: formKey,
          nameController: nameController,
          mobileController: mobileController,
          addressController: addressController,
          gstController: gstController,
          itemCount: itemCount,
          totalAmount: totalAmount,
          primaryColor: primaryColor,
          onCancel: () => Navigator.pop(context),
          onSave: (customerId) {
            if (formKey.currentState!.validate()) {
              onSave(customerId);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }

  // Connection listener is now setup in _setupConnectionListenerAsync()

  Future<void> _updatePendingBillsCount() async {
    if (adminUid.isNotEmpty && !adminUid.contains('Error') && !adminUid.contains('not found')) {
      final count = await _offlineBillManager.getOfflineBillsCount(adminUid);
      if (mounted) {
        setState(() {
          _pendingBillsCount = count;
        });
      }
    }
  }

  Future<void> _syncPendingBills() async {
    if (_isOnline && _pendingBillsCount > 0 && adminUid.isNotEmpty) {
      await _offlineBillManager.syncOfflineBills(adminUid: adminUid);
      _updatePendingBillsCount();
    }
  }

  Future<void> _initializeFoodItems() async {
    try {
      List<Map<String, dynamic>> departments = await foodDepartmentsFuture;
      if (departments.isNotEmpty) {
        setState(() {
          selectedDepartment = departments[0]['name'] ?? '';
          foodItemsFuture = fetchFoodItems(selectedDepartment);
        });
      } else {
        // Handle empty departments case so UI still loads
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> fetchAdminUid() async {
    try {
      final sqliteHelper = SQLiteHelper();
      final cachedUid = await sqliteHelper.getAdminUid(widget.phoneNo);
      if (cachedUid != null && cachedUid.isNotEmpty) {
        setState(() {
          adminUid = cachedUid;
        });
        return cachedUid;
      }
      setState(() {
        adminUid = widget.phoneNo;
      });
      return widget.phoneNo;
    } catch (e) {
      return await _getCachedAdminUid();
    }
  }

  /// Get cached adminUid from SQLite for offline use
  Future<String> _getCachedAdminUid() async {
    try {
      final sqliteHelper = SQLiteHelper();
      final cachedAdminUid = await sqliteHelper.getAdminUid(widget.phoneNo);

      if (cachedAdminUid != null && cachedAdminUid.isNotEmpty) {
        setState(() {
          adminUid = cachedAdminUid;
        });
        return cachedAdminUid;
      }

      // Last resort: use phoneNo as adminUid (common pattern in this app)
      setState(() {
        adminUid = widget.phoneNo;
      });
      return widget.phoneNo;
    } catch (e) {
      // Ultimate fallback: use phoneNo
      setState(() {
        adminUid = widget.phoneNo;
      });
      return widget.phoneNo;
    }
  }

  /// Fetch departments using CategoryService
  Future<List<Map<String, dynamic>>> fetchFoodDepartment() async {
    try {
      final categories = widget.role == 'customer'
          ? await CategoryService().getPublicCategories(widget.phoneNo)
          : await CategoryService().getCategories();

      // Map API models to UI expected names
      final departments = categories
          .map((cat) => {
                'id': cat.id ?? cat.name,
                'name': cat.name,
                'imageUrl': cat.imageUrl ?? 'N/A',
                'status': 'Active',
              })
          .toList();

      return departments;
    } catch (e) {
      return [];
    }
  }

  /// Fetch food items using ProductService
  Future<List<Map<String, dynamic>>> fetchFoodItems(String department) async {
    try {
      // Find the ID of the selected category based on the name
      List<Map<String, dynamic>> departments = await foodDepartmentsFuture;
      String? categoryId;
      for (var dept in departments) {
        if (dept['name'] == department) {
          categoryId = dept['id'];
          break;
        }
      }

      // Fetch products using the new API
      final products = widget.role == 'customer'
          ? await ProductService().getPublicProducts(widget.phoneNo, categoryId: categoryId)
          : await ProductService().getProducts(categoryId: categoryId);

      // Map API models to UI expected names
      final items = products.map((item) {
        return {
          'id': item.id ?? item.name,
          '_id': item.id,
          'name': item.name,
          'price': item.price.toString(),
          'price2': item.price2?.toString() ?? '0',
          'price3': item.price3?.toString() ?? '0',
          'priceType': item.priceType,
          'imagePath': item.imagePath ?? item.imageUrl ?? 'N/A',
          'foodCode': item.foodCode ?? 'N/A',
          'department': item.department ?? item.categoryId,
          'stocks': item.stocks ?? 'N/A',
          'baseVariant': item.baseVariant ?? '',
          'variants': item.variants ?? [],
          'addons': item.addons ?? [],
        };
      }).toList();

      setState(() {
        isLoading = false;
      });

      return items;
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      return [];
    }
  }

  int activeIndex = 0;

  Widget builImage(String urlImage, int index) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: grey,
        child: Image.network(urlImage, fit: BoxFit.cover),
      );

  // Connection status indicator widget
  Widget _buildConnectionStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: _isOnline ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          MyText(
            text: _isOnline ? 'Online' : 'Offline',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _isOnline ? Colors.green : Colors.orange,
          ),
          if (_pendingBillsCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: MyText(
                text: '$_pendingBillsCount pending',
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableSelector() {
    final tableProvider = Provider.of<TableProvider>(context);
    final orderTypeProvider = Provider.of<OrderTypeProvider>(context);
    if (orderTypeProvider.orderType != OrderType.dineIn) {
      return const SizedBox.shrink();
    }

    // Show loading indicator while tables are loading
    if (tableProvider.isLoading) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Hide table selector if no tables available
    if (tableProvider.tables.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tableProvider.tables.length,
        itemBuilder: (context, index) {
          final table = tableProvider.tables[index];
          final isSelected = tableProvider.selectedTableId == table.id;
          final hasItems = table.isOccupied;

          return GestureDetector(
            onTap: () => _handleTableSelection(table.id),
            onLongPress: () {
              if (hasItems) {
                _showTableSummaryDialog(table);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? appbar1
                    : hasItems
                        ? Colors.orange.shade100
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? appbar1
                      : hasItems
                          ? Colors.orange
                          : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: appbar1.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasItems ? Icons.receipt_long : Icons.table_restaurant_outlined,
                        size: 16,
                        color: isSelected ? Colors.white : (hasItems ? Colors.orange.shade800 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 5),
                      MyText(
                        text: table.tableNumber,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected || hasItems ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ],
                  ),
                  if (hasItems && !isSelected)
                    MyText(
                      text: 'Occupied',
                      color: Colors.orange.shade800,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTableSummaryDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: appbar1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyText(
                text: 'Table ${table.tableNumber} Summary',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (table.customerName != null && table.customerName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16),
                      const SizedBox(width: 8),
                      MyText(
                        text: '${table.customerName} (${table.customerPhone ?? 'No Phone'})',
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
              const MyText(
                text: 'Items',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: table.items.length,
                  itemBuilder: (context, index) {
                    final item = table.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: '${item['name']} x ${item['quantity']}',
                              fontSize: 13,
                            ),
                          ),
                          MyText(
                            text: '₹${(item['price'] * item['quantity']).toStringAsFixed(0)}',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const MyText(
                    text: 'Total Amount',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  MyText(
                    text: '₹${table.subtotal.toStringAsFixed(0)}',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: appbar1,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleTableSelection(table.id);
            },
            child: MyText(text: 'Switch to Table', color: appbar1, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: appbar1),
            child: const MyText(text: 'Close', color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _handleTableSelection(String tableId) {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    // Do NOT auto-save the current cart when switching tables.
    // The table backend is only updated when the user explicitly presses
    // the table save button (🪑). This ensures accidental edits or deletions
    // are never committed to the database silently.

    // 1. Select the new table
    tableProvider.selectTable(tableId);

    // 2. Load the selected table's saved cart into PrintProvider
    final newTable = tableProvider.tables.firstWhere((t) => t.id == tableId);
    printProvider.setCart(newTable.items, newTable.subtotal);
  }

  @override
  Widget build(BuildContext context) {
    final printprovider = Provider.of<PrintProvider>(context);
    // Sync local state with provider
    selectedItemsDetails = printprovider.posts;
    subtotal = printprovider.total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.role == 'customer'
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Showcase(
                key: TourKeys.drawerIconKey,
                title: 'Main Menu',
                description: 'Open this to access your Dashboard, Menu, Reports, and Settings.',
                child: Builder(builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu, color: primaryColor),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                }),
              ),
        title: isSearching
            ? Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: restaurantSearch,
                  autofocus: true,
                  onChanged: (value) {
                    search1 = value;
                    setState(() {});
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                      hintText: "Search Item Name",
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.all(15)),
                ),
              )
            : const MyText(
                text: 'Restaurants',
                color: Colors.black,
                fontSize: 17,
              ),
        actions: [
          if (_isDemoMode && _showTutorialActions)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () async {
                  ShowCaseWidget.of(context).dismiss();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_first_time_main_tutorial', false);
                  await prefs.setBool('is_first_time_detailed_tutorial', false);
                  await prefs.setBool('is_first_time_drawer_tutorial', false);
                  await prefs.setBool('has_visited_demo', true); // Ensure we don't reset it on next login
                  if (mounted) {
                    setState(() {
                      _showTutorialActions = false;
                    });
                  }
                },
                icon: const Icon(Icons.skip_next, color: Colors.orange, size: 18),
                label: const MyText(
                  text: 'Skip Tour',
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          if (!isSearching && widget.role != 'customer')
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildConnectionStatusIndicator(),
            ),

          // Fullscreen
          if (!isSearching)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                child: Icon(isContainerVisible ? MdiIcons.fullscreen : MdiIcons.fullscreenExit),
                onTap: () {
                  setState(() {
                    isContainerVisible = !isContainerVisible;
                    _gridViewController.jumpTo(0.0);
                  });
                },
              ),
            ),

          // Users
          if (!isSearching && widget.role != 'customer')
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UsersScreen()),
                  );
                },
                child: const Icon(Icons.save),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              child: CircleAvatar(
                maxRadius: 20,
                backgroundColor: appbar1,
                child: Icon(
                  isSearching ? Icons.search_off : Icons.search,
                  size: 22,
                  color: white,
                ),
              ),
              onTap: () {
                if (isSearching) {
                  restaurantSearch.clear();
                  search1 = '';
                }
                setState(() => isSearching = !isSearching);
              },
            ),
          ),
        ],
      ),
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          // Delay to ensure drawer is fully open
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              (_drawerKey.currentState as dynamic?)?.startDrawerTutorial?.call();
            }
          });
        }
      },
      drawer: widget.role == 'customer'
          ? null
          : MyDrawer(
              key: _drawerKey,
              phoneNo: widget.phoneNo,
              adminPhoneNo: adminUid,
              role: widget.role,
            ),
      body: isLoading
          ? Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: appbar1,
                  strokeWidth: 3,
                ),
              ),
            )
          : Container(
              color: Colors.grey.withOpacity(0.1),
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  if (widget.role != 'customer') ...[
                    Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      width: double.infinity,
                      child: const OrderTypeSelector(),
                    ),
                    Showcase(
                      key: TourKeys.tableSelectorKey,
                      title: 'Select Table',
                      description: 'Choose a table to assign this order. Tables marked in red are already occupied.',
                      child: _buildTableSelector(),
                    ),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        if (isContainerVisible)
                          SizedBox(
                            width: 80,
                            child: Showcase(
                              key: TourKeys.categoryListKey,
                              title: 'Food Categories',
                              description: 'Quickly switch between departments like Fast Food or Desserts.',
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.white),
                                padding: const EdgeInsets.only(left: 5),
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: foodDepartmentsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(child: MyText(text: 'Error: ${snapshot.error}'));
                                    } else {
                                      List<Map<String, dynamic>> departments = snapshot.data ?? [];
                                      return ListView.builder(
                                        itemCount: departments.length,
                                        itemBuilder: (context, index) {
                                          bool isSelected = currentCategoryIndex == index;
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                currentCategoryIndex = index;
                                                selectedDepartment = departments[index]['name'] ?? '';
                                                foodItemsFuture = fetchFoodItems(selectedDepartment);
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 15),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    children: [
                                                      Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          // Background Circle
                                                          AnimatedContainer(
                                                            duration: const Duration(milliseconds: 300),
                                                            curve: Curves.easeOut,
                                                            margin: const EdgeInsets.all(5),
                                                            height: 60,
                                                            width: 60,
                                                            decoration: BoxDecoration(
                                                              color: appbar1.withOpacity(0.15),
                                                              borderRadius: BorderRadius.circular(30),
                                                            ),
                                                          ),

                                                          // Image with scale animation
                                                          AnimatedScale(
                                                            scale: isSelected ? 1.1 : 1.0,
                                                            duration: const Duration(milliseconds: 300),
                                                            curve: Curves.easeIn,
                                                            child: CachedBlobImage(
                                                              imageUrl: departments[index]['imageUrl'],
                                                              tableName: 'departments',
                                                              recordId: departments[index]['id'] ??
                                                                  departments[index]['name'] ??
                                                                  'unknown',
                                                              width: 50,
                                                              height: 50,
                                                              fit: BoxFit.fill,
                                                              borderRadius: BorderRadius.circular(100),
                                                              placeholder: const SizedBox(
                                                                width: 20,
                                                                height: 20,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      // Text with animation
                                                      SizedBox(
                                                        width: 60,
                                                        child: MyText(
                                                          text: departments[index]['name'] ?? 'N/A',
                                                          textAlign: TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          fontSize: 12,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                          color: isSelected ? appbar1 : Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  // Side indicator
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeOut,
                                                    height: 50,
                                                    width: 5,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? appbar1 : Colors.white,
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(21),
                                                        bottomLeft: Radius.circular(21),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),

                        // MAIN BODY
                        Expanded(
                          child: FutureBuilder(
                            future: foodItemsFuture,
                            builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              } else if (snapshot.hasError) {
                                return Center(child: MyText(text: 'Error: ${snapshot.error}'));
                              } else {
                                List<Map<String, dynamic>> allFoodItems = snapshot.data ?? [];

                                List<Map<String, dynamic>> filteredFoodItems;

                                if (search1.isEmpty) {
                                  filteredFoodItems = allFoodItems;
                                } else {
                                  final query = search1.toLowerCase();

                                  filteredFoodItems = allFoodItems.where((item) {
                                    final name = item['name']?.toString().toLowerCase() ?? '';
                                    final code = item['foodCode']?.toString().toLowerCase() ?? '';

                                    return name.contains(query) || code.contains(query);
                                  }).toList();
                                }

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Showcase(
                                          key: TourKeys.firstProductKey,
                                          title: 'Add Items to Cart',
                                          description: 'Simply tap on any food item to add it to your current order.',
                                          child: GridView.builder(
                                            controller: _gridViewController,
                                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: isContainerVisible ? 150 : 140,
                                              childAspectRatio: isContainerVisible ? 0.86 : 0.8,
                                              crossAxisSpacing: 5,
                                              mainAxisSpacing: 6,
                                            ),
                                            itemCount: filteredFoodItems.length,
                                            itemBuilder: (context, index) {
                                              final item = filteredFoodItems[index];
                                              return MenuItem(
                                                context: context,
                                                imagePath: item['imagePath']?.toString() ?? '',
                                                text: item['name']?.toString() ?? '',
                                                code: item['foodCode']?.toString() ?? '',
                                                imagerecordId: item['_id']?.toString() ?? item['id']?.toString(),
                                                price: item['price']?.toString() ?? '0',
                                                price2: item['price2']?.toString() ?? '0',
                                                price3: item['price3']?.toString() ?? '0',
                                                priceType: item['priceType']?.toString() ?? 'Fixed',
                                                stocks: item['stocks']?.toString() ?? 'N/A',
                                                baseVariant: item['baseVariant']?.toString(),
                                                variants: item['variants'] as List<dynamic>?,
                                                addons: item['addons'] as List<dynamic>?,
                                                onAdd: (id, name, price, quantity, unit, unitQty, addOnList) {
                                                  audioPlayer.play(AssetSource('sounds/beep.mp3'));

                                                  setState(() {
                                                    isTapped = true;

                                                    final displayName =
                                                        unit.toString().isNotEmpty ? '$name ($unitQty $unit)' : name;

                                                    final parsedPrice = double.tryParse(price) ?? 0.0;

                                                    final existingIndex = selectedItemsDetails.indexWhere(
                                                      (element) =>
                                                          element['name'] == displayName &&
                                                          element['price'] == parsedPrice &&
                                                          element['productId'] == id,
                                                    );

                                                    if (existingIndex != -1) {
                                                      selectedItemsDetails[existingIndex]['quantity'] += quantity;
                                                      selectedItemsDetails[existingIndex]['addons'] = addOnList;
                                                    } else {
                                                      selectedItemsDetails.add({
                                                        'productId': id,
                                                        'name': displayName,
                                                        'price': parsedPrice,
                                                        'quantity': quantity,
                                                        'unit': unit,
                                                        'addons': addOnList,
                                                      });
                                                    }

                                                    subtotal += parsedPrice * quantity;

                                                    printprovider.additem(selectedItemsDetails, subtotal);

                                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                                      if (_listScrollController.hasClients) {
                                                        _listScrollController.jumpTo(
                                                          _listScrollController.position.maxScrollExtent,
                                                        );
                                                      }
                                                    });
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ));
                                  },
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  printprovider.posts.isNotEmpty
                      ? BillCart(
                          isContainerVisible: isContainerVisible,
                          isRestaurantScreen: true,
                          adminUid: adminUid,
                          phoneNo: widget.phoneNo,
                          role: widget.role,
                          onCartCleared: () {
                            setState(() {
                              selectedItemsDetails.clear();
                              subtotal = 0.0;
                            });
                          },
                          onCartUpdated: (List<Map<String, dynamic>> updatedItems, double updatedTotal) {
                            setState(() {
                              selectedItemsDetails = updatedItems;
                              subtotal = updatedTotal;
                            });
                          },
                          onPlaceOrder: widget.role == 'customer'
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CustomerOrderSummary(
                                        items: List.from(selectedItemsDetails),
                                        totalAmount: subtotal,
                                        adminId: adminUid,
                                        customerId: customerId,
                                        customerName: userNameController.text,
                                        customerPhone: userPhoneController.text,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          orderBottomSheet: () {
                            showSaveOrderBottomSheet(
                              context: context,
                              formKey: _formKey,
                              nameController: userNameController,
                              addressController: addressController,
                              gstController: gstController,
                              mobileController: userPhoneController,
                              itemCount: selectedItemsDetails.length,
                              totalAmount: subtotal,
                              primaryColor: primaryColor,
                              onSave: (customerId) {
                                _saveDataAndNavigate(customerId);
                                printprovider.clearCart();
                                userNameController.clear();
                                userPhoneController.clear();
                              },
                            );
                          },
                        )
                      : const SizedBox(),
                ],
              ),
            ),
    );
  }

  Future<void> _showSaveBottomSheet() async {
    final printprovider = Provider.of<PrintProvider>(context, listen: false);

    return showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userNameController,
                  decoration: const InputDecoration(labelText: 'User Name'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter a user name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _saveDataAndNavigate(null); // No customer ID selected in this manual sheet
                      printprovider.clearCart();
                      userNameController.clear();
                    }
                  },
                  child: const MyText(text: 'Submit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveDataAndNavigate(String? customerId) async {
    final userMap = {
      'phoneNumber': userPhoneController.text,
      'userName': userNameController.text,
      'details': selectedItemsDetails,
      'totalAmount': subtotal,
      'customerId': customerId ?? (widget.role == 'customer' ? widget.phoneNo : null),
      'adminId': adminUid,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Save data to Hive (Local backup)
    final box = await Hive.openBox('userBox');
    box.add(userMap);

    // 2. Transmit to server
    if (adminUid.isNotEmpty && !adminUid.contains('Error')) {
      SnackBarUtils.showInfo(context, 'Placing order...');

      try {
        final orderService = OrderService();

        // Get table info if in Dine In mode
        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
        String? tableNumber;
        String? existingOrderId;

        if (orderTypeProvider.orderType == OrderType.dineIn && tableProvider.selectedTableId != null) {
          tableNumber = tableProvider.selectedTable?.tableNumber;
          existingOrderId = tableProvider.selectedTable?.lastOrderId;
        }

        // Prepare items with 'total' field for backend
        final formattedItems = selectedItemsDetails.map((item) {
          return {
            ...item,
            'total': (item['price'] as num) * (item['quantity'] as num),
          };
        }).toList();

        OrderModel resultOrder;

        if (widget.role == 'customer') {
          resultOrder = await orderService.createGuestOrder(
            adminId: adminUid,
            customerName: userNameController.text,
            customerPhone: userPhoneController.text,
            items: formattedItems,
            orderType: 'Pickup',
            tableNumber: tableNumber,
            billNumber: existingOrderId, // Reuse ID if available
          );
        } else {
          resultOrder = await orderService.createOrder(
            adminId: adminUid,
            // If we have an existing ID, use it. Otherwise, generate a new one.
            billNumber: existingOrderId ?? 'POS-RS-${DateTime.now().millisecondsSinceEpoch}',
            customerName: userNameController.text,
            customerPhone: userPhoneController.text,
            customerId: customerId ?? (widget.role == 'customer' ? widget.phoneNo : null),
            items: formattedItems,
            orderType: orderTypeProvider.orderType.toString().split('.').last,
            paymentMethod: orderTypeProvider.paymentType.toString().split('.').last,
            paymentStatus: 'Due',
            tableNumber: tableNumber,
            createKot: tableNumber == null,
          );
        }

        // 3. Update the table with the order ID and customer info so it appears occupied
        if (tableNumber != null && tableProvider.selectedTableId != null) {
          // Ensure the table reflects occupancy and customer details in the SQLite database
          await tableProvider.setTableCart(
            tableProvider.selectedTableId!,
            selectedItemsDetails,
            customerName: userNameController.text,
            customerPhone: userPhoneController.text,
            lastOrderId: resultOrder.id,
            createKot: false,
          );
        }

        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Order placed successfully!');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showWarning(context, 'Failed to sync with server. Saved locally.');
        }
      }
    }

    userNameController.clear();
    userPhoneController.clear();

    if (mounted) {
      if (widget.role == 'customer') {
        SnackBarUtils.showSuccess(context, 'Order placed successfully!');
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UsersScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();

    userNameController.dispose();
    userPhoneController.dispose();
    _listScrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}
