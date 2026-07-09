// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Project imports:
import 'package:pos/data/services/category_service.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/data/models/table_model.dart';
import 'package:pos/data/models/order_model.dart';
import '../widgets/bill_cart_widget.dart';
import '../widgets/show_save_order_bottom_sheet.dart';
import 'package:pos/l10n/app_locale.dart';

class RestaurantScreen extends StatefulWidget {
  final bool isEditBill;
  final String? receiptNo;
  final String? role;
  const RestaurantScreen({Key? key, this.isEditBill = false, this.receiptNo, this.role}) : super(key: key);

  @override
  _RestaurantScreenState createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  String phoneNo = '';
  String adminUid = '';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  AudioPlayer audioPlayer = AudioPlayer();
  String selectedItemName = '';
  int selectedItemPrice = 0;
  double subtotal = 0.0;
  int currentCategoryIndex = 0;
  String? customerId;
  bool _isDemoMode = false;
  bool _showTutorialActions = false;
  String selectedDepartment = '';
  String businessCategory = 'Food';
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
  bool isSearching = false;
  String search1 = '';

  TextEditingController restaurantSearch = TextEditingController();

  DateTime? currentBackPressTime;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _tourShowing = false;
  TutorialCoachMark? _tourMark;
  TourProvider? _tourProvider;

  void _onTourStateChanged() {
    if (!mounted) return;
    final tourProvider = context.read<TourProvider>();
    if (tourProvider.isTourActive && tourProvider.currentStep == 17 && !_tourShowing) {
      _tourShowing = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && tourProvider.isTourActive && tourProvider.currentStep == 17) {
          _showTour();
        } else {
          _tourShowing = false;
        }
      });
    } else if (tourProvider.isTourActive && tourProvider.currentStep == 29) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && tourProvider.isTourActive && tourProvider.currentStep == 29) {
          _scaffoldKey.currentState?.openDrawer();
          tourProvider.setStep(30);
        }
      });
    }
  }

  void _showTour() {
    final tourProvider = context.read<TourProvider>();
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final targets = [
      TargetFocus(
        identify: "pos_drawer",
        keyTarget: TourKeys.restaurantDrawerIconKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 17,
                title: AppLocale.tourTitle14.getString(context),
                description: AppLocale.tourDesc14.getString(context),
                onNext: () => controller.next(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "pos_table",
        keyTarget: TourKeys.tableSelectorKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 18,
                title: AppLocale.tourTitle15.getString(context),
                description: AppLocale.tourDesc15.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "pos_product",
        keyTarget: TourKeys.firstProductKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 19,
                title: AppLocale.tourTitle16.getString(context),
                description: AppLocale.tourDesc16.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
    ];

    final validTargets = targets.where((t) {
      final k = t.keyTarget;
      return k == null || k.currentContext != null;
    }).toList();
    if (validTargets.isEmpty) {
      _tourShowing = false;
      if (tourProvider.isTourActive) {
        if (printProvider.posts.isEmpty) {
          printProvider.additem([
            {
              'id': 'demo_product_id',
              'name': 'Demo Burger',
              'price': '150.0',
              'quantity': 1,
              'unit': 'pcs',
              'addons': [],
            }
          ], 150.0);
        }
        tourProvider.setStep(20);
      }
      return;
    }

    _tourMark = TutorialCoachMark(
      targets: validTargets,
      hideSkip: true,
      colorShadow: Colors.black.withOpacity(0.85),
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        _tourShowing = false;
        if (tourProvider.isTourActive) {
          if (printProvider.posts.isEmpty) {
            printProvider.additem([
              {
                'id': 'demo_product_id',
                'name': 'Demo Burger',
                'price': '150.0',
                'quantity': 1,
                'unit': 'pcs',
                'addons': [],
              }
            ], 150.0);
          }
          tourProvider.setStep(20);
        }
      },
      onSkip: () {
        _tourShowing = false;
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
  }

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _tourProvider = context.read<TourProvider>();
    _tourProvider!.addListener(_onTourStateChanged);
  }

  @override
  void dispose() {
    _tourProvider?.removeListener(_onTourStateChanged);
    audioPlayer.dispose();
    userNameController.dispose();
    userPhoneController.dispose();
    addressController.dispose();
    gstController.dispose();
    restaurantSearch.dispose();
    _listScrollController.dispose();
    _gridViewController.dispose();
    _tourMark?.finish();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
      businessCategory = prefs.getString('businessCategory') ?? 'Food';
    });
    _initializeAll();
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

  /// Initialize all services efficiently
  Future<void> _initializeAll() async {
    // Load business category
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      businessCategory = prefs.getString('businessCategory') ?? 'Food';
    });

    // Load data from online API
    foodDepartmentsFuture = fetchFoodDepartment();
    _initializeFoodItems();
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

  Future<void> _initializeFoodItems() async {
    try {
      List<Map<String, dynamic>> departments = await foodDepartmentsFuture;
      if (!mounted) return;
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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<String> fetchAdminUid() async {
    try {
      if (!mounted) return phoneNo;
      setState(() {
        adminUid = phoneNo;
      });
      return phoneNo;
    } catch (e) {
      return phoneNo;
    }
  }

  /// Fetch departments using CategoryService
  Future<List<Map<String, dynamic>>> fetchFoodDepartment() async {
    try {
      final categories = await CategoryService().getCategories();

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
      final products = await ProductService().getProducts(categoryId: categoryId);

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

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return items;
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
  // ignore: unused_element
  Widget _buildConnectionStatusIndicator() {
    // Online-only mode - no offline status needed
    return const SizedBox.shrink();
  }

  Widget _buildTableSelector() {
    final tableProvider = Provider.of<TableProvider>(context);
    final orderTypeProvider = Provider.of<OrderTypeProvider>(context);
    if (orderTypeProvider.orderType != OrderType.dineIn || businessCategory != 'Food') {
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
                boxShadow: isSelected ? [BoxShadow(color: appbar1.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
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
                      text: AppLocale.occupied.getString(context),
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
          decoration: const BoxDecoration(
            color: appbar1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyText(
                text: '${AppLocale.tables.getString(context)} ${table.tableNumber} ${AppLocale.orderSummary.getString(context)}',
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
                        text: '${table.customerName} (${table.customerPhone ?? ''})',
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
              MyText(
                text: AppLocale.items.getString(context),
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
                  MyText(
                    text: AppLocale.totalAmount.getString(context),
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
            child: MyText(text: AppLocale.switchToTable.getString(context), color: appbar1, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: appbar1),
            child: MyText(text: AppLocale.close.getString(context), color: Colors.white),
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
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(
            key: TourKeys.restaurantDrawerIconKey,
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
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
                    decoration: InputDecoration(
                        hintText: AppLocale.searchItemName.getString(context),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.all(15)),
                  ),
                )
              : MyText(
                  text: businessCategory == 'Food' ? AppLocale.restaurants.getString(context) : AppLocale.billingAndPos.getString(context),
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            if (_isDemoMode && _showTutorialActions)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: () async {
                    context.read<TourProvider>().stopTour();
                    _tourMark?.finish();
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
                  label: MyText(
                    text: AppLocale.skipTour.getString(context),
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
            // if (!isSearching)
            //   Padding(
            //     padding: const EdgeInsets.only(right: 12.0),
            //     child: _buildConnectionStatusIndicator(),
            //   ),

            // Fullscreen
            if (!isSearching)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  child: Icon(isContainerVisible ? CommunityMaterialIcons.fullscreen : CommunityMaterialIcons.fullscreen_exit),
                  onTap: () {
                    setState(() {
                      isContainerVisible = !isContainerVisible;
                      _gridViewController.jumpTo(0.0);
                    });
                  },
                ),
              ),

            // Users
            if (!isSearching)
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
                (_drawerKey.currentState as dynamic)?.startDrawerTutorial?.call();
              }
            });
          }
        },
        drawer: MyDrawer(
          key: _drawerKey,
          phoneNo: phoneNo,
          adminPhoneNo: adminUid,
        ),
        body: isLoading
            ? const _RestaurantFullSkeleton()
            : Container(
                color: Colors.grey.withOpacity(0.1),
                width: double.infinity,
                height: double.infinity,
                child: Stack(children: [
                  Column(
                    children: [
                      if (businessCategory == 'Food')
                        Container(
                          height: 50,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          width: double.infinity,
                          child: const OrderTypeSelector(),
                        ),
                      if (businessCategory == 'Food')
                        KeyedSubtree(
                          key: TourKeys.tableSelectorKey,
                          child: _buildTableSelector(),
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            if (isContainerVisible)
                              SizedBox(
                                width: 80,
                                child: Container(
                                  key: TourKeys.categoryListKey,
                                  decoration: const BoxDecoration(color: Colors.white),
                                  padding: const EdgeInsets.only(left: 5),
                                  child: FutureBuilder<List<Map<String, dynamic>>>(
                                    future: foodDepartmentsFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const _CategorySkeleton();
                                      } else if (snapshot.hasError) {
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
                                                                recordId: departments[index]['id'] ?? departments[index]['name'] ?? 'unknown',
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

                            // MAIN BODY
                            Expanded(
                              child: FutureBuilder(
                                future: foodItemsFuture,
                                builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const _ProductGridSkeleton();
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
                                              final menuItem = MenuItem(
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

                                                    final displayName = unit.toString().isNotEmpty ? '$name ($unitQty $unit)' : name;

                                                    final parsedPrice = double.tryParse(price) ?? 0.0;

                                                    final existingIndex = selectedItemsDetails.indexWhere(
                                                      (element) => element['name'] == displayName && element['price'] == parsedPrice && element['productId'] == id,
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
                                              if (index == 0) {
                                                return KeyedSubtree(
                                                  key: TourKeys.firstProductKey,
                                                  child: menuItem,
                                                );
                                              }
                                              return menuItem;
                                            },
                                          ),
                                        );
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
                              onPlaceOrder: null,
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
                ]),
              ));
  }

  // ignore: unused_element
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
                  decoration: InputDecoration(labelText: AppLocale.userName.getString(context)),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return AppLocale.pleaseEnterUserName.getString(context);
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
                  child: MyText(text: AppLocale.submit.getString(context)),
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
      'customerId': customerId,
      'adminId': adminUid,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Save data to Hive (Local backup)
    final box = await Hive.openBox('userBox');
    box.add(userMap);

    // 2. Transmit to server
    if (adminUid.isNotEmpty && !adminUid.contains('Error')) {
      SnackBarUtils.showInfo(context, AppLocale.placingOrder.getString(context));

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

        resultOrder = await orderService.createOrder(
          adminId: adminUid,
          // If we have an existing ID, use it. Otherwise, generate a new one.
          billNumber: existingOrderId ?? 'POS-RS-${DateTime.now().millisecondsSinceEpoch}',
          customerName: userNameController.text,
          customerPhone: userPhoneController.text,
          customerId: customerId,
          items: formattedItems,
          orderType: orderTypeProvider.orderType.toString().split('.').last,
          paymentMethod: orderTypeProvider.paymentType.toString().split('.').last,
          paymentStatus: 'Due',
          tableNumber: tableNumber,
          createKot: businessCategory == 'Food' && tableNumber == null,
        );

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
          SnackBarUtils.showSuccess(context, AppLocale.orderPlacedSuccessfully.getString(context));
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showWarning(context, AppLocale.failedToSyncSavedLocally.getString(context));
        }
      }
    }

    userNameController.clear();
    userPhoneController.clear();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UsersScreen()),
      );
    }
  }
}

class _RestaurantFullSkeleton extends StatelessWidget {
  const _RestaurantFullSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const Expanded(
          child: Row(
            children: [
              SizedBox(width: 80, child: _CategorySkeleton()),
              Expanded(child: _ProductGridSkeleton()),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 15, left: 10),
            child: Column(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 10,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }
}
