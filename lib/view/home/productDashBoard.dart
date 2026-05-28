// Dart imports:
import 'dart:async';
import 'dart:developer' as developer;

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/view/home/screens/dashboard.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/data/services/order_service.dart';
import 'widgets/bill_cart_widget.dart';
import 'widgets/show_save_order_bottom_sheet.dart';

import 'package:pos/view/tab_screen/view-model/widgets/offline_status_banner.dart' as banner;

class ProductDashBoard extends StatefulWidget {
  const ProductDashBoard({Key? key}) : super(key: key);

  @override
  State<ProductDashBoard> createState() => _ProductDashBoardState();
}

class _ProductDashBoardState extends State<ProductDashBoard> {
  String phoneNo = '';
  String adminId = '';

  TextEditingController search = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController gstController = TextEditingController();
  String search1 = '';
  final ScrollController _listScrollController = ScrollController();
  AudioPlayer audioPlayer = AudioPlayer();
  String selectedItemName = '';
  int selectedItemPrice = 0;
  double subtotal = 0.0;
  String adminUid = '';
  late Future<List<Map<String, dynamic>>> foodItemsFuture;
  List<Map<String, dynamic>> selectedItemsDetails = [];
  bool isTapped = false;
  bool isLoading = false;
  Map<String, dynamic> userData = {};
  bool isSearching = false;
  String businessCategory = 'Food';
  TextEditingController searchController = TextEditingController();
  bool _tourShowing = false;
  TutorialCoachMark? _tourMark;

  void _onTourStateChanged() {
    if (!mounted) return;
    final tourProvider = context.read<TourProvider>();
    if (tourProvider.isTourActive && tourProvider.currentStep == 11 && !_tourShowing) {
      _tourShowing = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && tourProvider.isTourActive && tourProvider.currentStep == 11) {
          _showTour();
        } else {
          _tourShowing = false;
        }
      });
    }
  }

  void _showTour() {
    final tourProvider = context.read<TourProvider>();
    final targets = [
      TargetFocus(
        identify: "prod_dash_order_type",
        keyTarget: TourKeys.productDashOrderTypeKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 11,
                title: AppLocale.tourTitleProductDash.getString(context),
                description: AppLocale.tourDescProductDash.getString(context),
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
        identify: "prod_dash_search",
        keyTarget: TourKeys.productDashSearchKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 12,
                title: AppLocale.tourTitleProductSearch.getString(context),
                description: AppLocale.tourDescProductSearch.getString(context),
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
        identify: "https://www.designfolio.me/resume-signup",
        keyTarget: TourKeys.productDashGridKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(bottom: 24),
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 13,
                title: AppLocale.tourTitleProductGrid.getString(context),
                description: AppLocale.tourDescProductGrid.getString(context),
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
        tourProvider.setStep(14);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Dashboard()));
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
          tourProvider.setStep(14);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const Dashboard()));
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
    foodItemsFuture = _fetchProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TourProvider>().addListener(_onTourStateChanged);
      _onTourStateChanged();
    });
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminId = prefs.getString('adminUid') ?? '';
      adminUid = adminId;
      businessCategory = prefs.getString('businessCategory') ?? 'Food';
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    try {
      final products = await ProductService().getProducts();
      return products.map((p) => p.toJson()).toList();
    } catch (e) {
      developer.log('Error fetching products: $e', name: 'ProductDashBoard');
      return [];
    }
  }

  Future<void> showSaveOrderBottomSheet({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController mobileController,
    required TextEditingController addressController,
    required TextEditingController gstController,
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
          gstController: gstController,
          addressController: addressController,
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

  bool isSearchExpanded = false;
  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    final printprovider = Provider.of<PrintProvider>(
      context,
    );
    selectedItemsDetails = printprovider.posts;
    subtotal = printprovider.total;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
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
                  controller: searchController,
                  autofocus: true,
                  onChanged: (value) {
                    search1 = value;
                    setState(() {});
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration:
                      InputDecoration(hintText: AppLocale.searchItemName.getString(context), prefixIcon: const Icon(Icons.search, size: 18), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.all(15)),
                ),
              )
            : Row(
                children: [
                  MyText(
                    text: AppLocale.productDashboard.getString(context),
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  // SizedBox(width: 8),
                  // OfflineStatusIndicator(showWhenOnline: true),
                ],
              ),
        actions: [
          // Padding(
          //   padding: const EdgeInsets.only(right: 10.0),
          //   child: GestureDetector(
          //     child: const CircleAvatar(
          //         maxRadius: 20,
          //         backgroundColor: appbar1,
          //         child: Icon(
          //           Icons.barcode_reader,
          //           size: 22,
          //           color: Colors.white,
          //         )),
          //     onTap: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => const BarcodeScannerScreen(),
          //         ),
          //       );
          //     },
          //   ),
          // ),
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: isSearching
                ? GestureDetector(
                    child: const CircleAvatar(
                        maxRadius: 20,
                        backgroundColor: appbar1,
                        child: Icon(
                          Icons.search_off,
                          size: 22,
                          color: Colors.white,
                        )),
                    onTap: () {
                      searchController.clear();
                      search1 = '';
                      isSearching = false;
                      setState(() {});
                    },
                  )
                : GestureDetector(
                    key: TourKeys.productDashSearchKey,
                    child: const CircleAvatar(
                        maxRadius: 20,
                        backgroundColor: appbar1,
                        child: Icon(
                          Icons.search,
                          size: 22,
                          color: Colors.white,
                        )),
                    onTap: () {
                      isSearching = true;
                      setState(() {});
                    },
                  ),
          ),
        ],
      ),
      drawer: MyDrawer(
        phoneNo: phoneNo,
        adminPhoneNo: adminUid,
      ),
      body: Column(
        children: [
          banner.OfflineStatusBanner(adminUid: adminUid),
          Expanded(
            child: FutureBuilder(
              future: foodItemsFuture,
              builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ProductSkeleton();
                } else if (snapshot.hasError) {
                  return Center(
                    child: MyText(text: '${AppLocale.error.getString(context)}: ${snapshot.error}'),
                  );
                } else {
                  List<Map<String, dynamic>> foodItemsList = snapshot.data ?? [];
                  // Filter items based on search
                  List<Map<String, dynamic>> filteredItems = foodItemsList.where((item) => item['name'].toString().toLowerCase().contains(search1.toLowerCase())).toList();

                  return Column(
                    children: [
                      if (businessCategory == 'Food')
                        Container(
                          key: TourKeys.productDashOrderTypeKey,
                          height: 50,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          width: double.infinity,
                          child: const OrderTypeSelector(),
                        ),

                      // billCountContainer(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          child: GridView.builder(
                            key: TourKeys.productDashGridKey,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 170,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
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

                                    final displayName = unit.toString().isNotEmpty ? '$name ($unitQty $unit)' : name;

                                    final parsedPrice = double.tryParse(price) ?? 0.0;

                                    // 🔍 Check if same item + same unit already exists
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

                                    // Update backend table cart if a table is selected
                                    final tableProvider = Provider.of<TableProvider>(context, listen: false);
                                    if (tableProvider.selectedTableId != null) {
                                      tableProvider.setTableCart(tableProvider.selectedTableId!, selectedItemsDetails);
                                    }

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
                        ),
                      ),
                      printprovider.posts.isEmpty
                          ? const SizedBox()
                          : BillCart(
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
                                  nameController: nameController,
                                  mobileController: mobileController,
                                  itemCount: selectedItemsDetails.length,
                                  addressController: addressController,
                                  gstController: gstController,
                                  totalAmount: subtotal,
                                  primaryColor: primaryColor,
                                  onSave: (customerId) {
                                    _saveDataAndNavigate(customerId);
                                    printprovider.clearCart();
                                    nameController.clear();
                                    mobileController.clear();
                                    developer.log('Order saved with id: $customerId for ${nameController.text}, ${mobileController.text}', name: 'ProductDashBoard');
                                  },
                                );
                              },
                            ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _saveDataAndNavigate(String? customerId) async {
    final effectiveAdminId = adminUid;

    final userMap = {
      'userName': nameController.text,
      'phoneNumber': mobileController.text,
      'details': _encodeDetails(selectedItemsDetails),
      'totalAmount': subtotal,
      'customerId': customerId,
      'status': 'Pending',
      'timestamp': DateTime.now().toIso8601String(),
      'adminId': effectiveAdminId,
    };

    // 1. Save data to Hive (Local backup)
    final box = await Hive.openBox('userBox');
    box.add(userMap);

    // 2. Transmit to server if online/customer
    if (effectiveAdminId.isNotEmpty) {
      if (mounted) {
        SnackBarUtils.showInfo(context, AppLocale.placingOrder.getString(context));
      }

      try {
        final orderService = OrderService();

        // Prepare items with 'total' field for backend
        final formattedItems = selectedItemsDetails.map((item) {
          return {
            ...item,
            'total': (item['price'] as num) * (item['quantity'] as num),
          };
        }).toList();

        await orderService.createOrder(
          adminId: effectiveAdminId,
          billNumber: 'POS-${DateTime.now().millisecondsSinceEpoch}',
          customerName: nameController.text,
          customerPhone: mobileController.text,
          customerId: customerId,
          items: formattedItems,
          orderType: 'Pickup',
          paymentMethod: 'Cash',
          paymentStatus: 'Due',
        );

        if (mounted) {
          SnackBarUtils.showSuccess(context, AppLocale.orderPlacedSuccessfully.getString(context));
        }
        developer.log('Order successfully synced to server', name: 'ProductDashBoard');
      } catch (e) {
        developer.log('Failed to sync order to server: $e', name: 'ProductDashBoard');
        if (mounted) {
          SnackBarUtils.showWarning(context, AppLocale.failedToSyncOrderSavedLocally.getString(context));
        }
      }
    }

    nameController.clear();
    mobileController.clear();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UsersScreen(),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _encodeDetails(List<Map<String, dynamic>> details) {
    return details.map((item) {
      return {
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'],
      };
    }).toList();
  }

  @override
  void dispose() {
    try {
      context.read<TourProvider>().removeListener(_onTourStateChanged);
    } catch (_) {}
    _tourMark?.finish();
    search.dispose();
    nameController.dispose();
    mobileController.dispose();
    _listScrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
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
            ),
          ),
        ),
      ],
    );
  }
}
