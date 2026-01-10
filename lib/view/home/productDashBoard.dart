// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:pos/core/error/network_error_handler.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/offline_bill_status_screen.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/reports/billWise_report.dart';
import 'package:pos/view/home/reports/dateWise_report.dart';
import 'package:pos/view/home/reports/itemWise_report.dart';
import 'package:pos/view/home/screens/customer_list_screen.dart';
import 'package:pos/view/home/screens/edit_bill_receipt.dart';
import 'package:pos/view/home/screens/sales_report_screen.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/login/screens/inception_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:pos/view/tab_screen/view-model/widgets/offline_status_indicator.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/view/tab_screen/view-model/widgets/sync_status_page.dart';
import 'widgets/bill_cart_widget.dart';
import 'widgets/show_save_order_bottom_sheet.dart';

import 'package:pos/view/tab_screen/view-model/widgets/offline_status_banner.dart' as banner;

class ProductDashBoard extends StatefulWidget {
  final String phoneNo;

  const ProductDashBoard({required this.phoneNo, Key? key}) : super(key: key);

  @override
  State<ProductDashBoard> createState() => _ProductDashBoardState();
}

class _ProductDashBoardState extends State<ProductDashBoard> {
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
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map<String, dynamic> userData = {};
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    foodItemsFuture = fetchFoodItems();
    // fetchUserData();
  }

  Future<String> fetchAdminUid() async {
    // Try Firebase with short timeout - DatabaseService handles offline data
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('AllCustomer')
          .doc(widget.phoneNo)
          .get()
          .timeout(const Duration(seconds: 3));

      final data = snapshot.data();
      final String? fetchedAdminUid = data?['adminUid'];

      if (fetchedAdminUid != null && fetchedAdminUid.isNotEmpty) {
        // Cache the admin data in SQLite for offline use
        try {
          final sqliteHelper = SQLiteHelper();
          await sqliteHelper.saveAdminData({
            'adminUid': fetchedAdminUid,
            'phoneNumber': widget.phoneNo,
            'name': data?['name'],
            'email': data?['email'],
            'customerCode': data?['customerCode'],
            'createdAt': data?['createdAt'],
          });
        } catch (cacheError) {
          developer.log('Error caching adminUid in SQLite: $cacheError', name: 'ProductDashBoard');
        }

        if (mounted) {
          setState(() {
            adminUid = fetchedAdminUid;
          });
        }
        return fetchedAdminUid;
      }

      // If Firebase returned null, try SQLite cache
      return await _getCachedAdminUid();
    } catch (e) {
      developer.log('Error fetching adminUid: $e', name: 'ProductDashBoard');
      // Fall back to cached adminUid from SQLite when offline
      return await _getCachedAdminUid();
    }
  }

  /// Get cached adminUid from SQLite for offline use
  Future<String> _getCachedAdminUid() async {
    try {
      final sqliteHelper = SQLiteHelper();
      final cachedAdminUid = await sqliteHelper.getAdminUid(widget.phoneNo);

      if (cachedAdminUid != null && cachedAdminUid.isNotEmpty) {
        developer.log('Using cached adminUid from SQLite: $cachedAdminUid', name: 'ProductDashBoard');
        if (mounted) {
          setState(() {
            adminUid = cachedAdminUid;
          });
        }
        return cachedAdminUid;
      }

      // Last resort: use phoneNo as adminUid (common pattern in this app)
      developer.log('No cached adminUid found, using phoneNo as fallback', name: 'ProductDashBoard');
      if (mounted) {
        setState(() {
          adminUid = widget.phoneNo;
        });
      }
      return widget.phoneNo;
    } catch (e) {
      developer.log('Error getting cached adminUid from SQLite: $e', name: 'ProductDashBoard');
      // Ultimate fallback: use phoneNo
      if (mounted) {
        setState(() {
          adminUid = widget.phoneNo;
        });
      }
      return widget.phoneNo;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFoodItems() async {
    try {
      final String adminUid = await fetchAdminUid();
      final DatabaseService databaseService = Provider.of<DatabaseService>(context, listen: false);

      // Get all food items using DatabaseService
      final List<Map<String, dynamic>> allItems = await databaseService.getFoodItems(adminUid);

      // Debug: show count and sample types
      developer.log('All items count: ${allItems.length}', name: 'ProductDashBoard');
      if (allItems.isNotEmpty) {
        developer.log('First item keys: ${allItems.first.keys.toList()}', name: 'ProductDashBoard');
        developer.log('First item sample: ${allItems.first}', name: 'ProductDashBoard');
      }

      final List<Map<String, dynamic>> hotItems = allItems.map((item) {
        List<dynamic> parsedVariants = [];
        try {
          if (item['variants'] != null && item['variants'].toString().isNotEmpty) {
            parsedVariants = jsonDecode(item['variants'].toString());
          }
        } catch (e) {
          parsedVariants = [];
        }
        return {
          'id': item['id'] ?? item['name'],
          'name': item['name'] ?? 'N/A',
          'price': PriceUtils.safePriceToString(item['price']),
          'imagePath': item['image_path'] ?? item['imagePath'] ?? 'N/A',
          'description': item['description'] ?? 'N/A',
          'foodCode': item['foodCode'] ?? item['food_code'] ?? item['foodcode'] ?? 'N/A',
          'stocks': item['stocks'] ?? 'N/A',
          'baseVariant': item['baseVariant'] ?? '',
          'variants': parsedVariants,
        };
      }).toList();

      // Log for debugging
      developer.log('Fetched hot food items (count ${hotItems.length}): $hotItems', name: 'ProductDashBoard');
      developer.log('adminNO: $adminUid', name: 'ProductDashBoard');
      developer.log('All food items (unfiltered): $allItems', name: 'ProductDashBoard');

      return hotItems;
    } catch (e, st) {
      NetworkErrorHandler.logNetworkError(e, 'ProductDashBoard', 'fetchFoodItems');
      developer.log('Stack trace: $st', name: 'ProductDashBoard');
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
    required VoidCallback onSave,
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
          onSave: () {
            if (formKey.currentState!.validate()) {
              onSave();
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

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        // Handle double back press to exit the app
        DateTime now = DateTime.now();
        if (currentBackPressTime == null || now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
          currentBackPressTime = now;
          Fluttertoast.showToast(
            msg: "Press back again to exit",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 2,
            backgroundColor: Colors.grey,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          // Exit the app
          exit(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.green[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
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
                    decoration: const InputDecoration(
                        hintText: "Search Item Name",
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.all(15)),
                  ),
                )
              : const OfflineStatusIndicator(showWhenOnline: true),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: isSearching
                  ? GestureDetector(
                      child: CircleAvatar(
                          maxRadius: 20,
                          backgroundColor: appbar1,
                          child: const Icon(
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
                      child: CircleAvatar(
                          maxRadius: 20,
                          backgroundColor: appbar1,
                          child: const Icon(
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
        drawer: MyDrawer(phoneNo: widget.phoneNo),
        body: Column(
          children: [
            banner.OfflineStatusBanner(adminUid: adminUid),
            Expanded(
              child: FutureBuilder(
                future: foodItemsFuture,
                builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: appbar1,
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  } else {
                    List<Map<String, dynamic>> foodItemsList = snapshot.data ?? [];
                    // Filter items based on search
                    List<Map<String, dynamic>> filteredItems = foodItemsList
                        .where((item) => item['name'].toString().toLowerCase().contains(search1.toLowerCase()))
                        .toList();

                    return Column(
                      children: [
                        Container(
                          height: 50,
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          width: double.infinity,
                          child: const OrderTypeSelector(),
                        ),

                        // billCountContainer(),
                        Expanded(
                          child: LayoutBuilder(builder: (context, constraints) {
                            // Calculate number of columns based on screen width
                            int crossAxisCount;
                            double childAspectRatio;
                            double horizontalPadding;
                            double spacing;
                            double availableWidth = constraints.maxWidth;

                            if (availableWidth > 1400) {
                              crossAxisCount = 5;
                              childAspectRatio = 0.80;
                              horizontalPadding = 16;
                              spacing = 16;
                            } else if (availableWidth > 1000) {
                              crossAxisCount = 4;
                              childAspectRatio = 0.78;
                              horizontalPadding = 12;
                              spacing = 12;
                            } else if (availableWidth > 700) {
                              crossAxisCount = 3;
                              childAspectRatio = 0.75;
                              horizontalPadding = 10;
                              spacing = 10;
                            } else {
                              // For smaller screens (phones), always 2 columns
                              crossAxisCount = 3;
                              childAspectRatio = 0.6;
                              horizontalPadding = 5;
                              spacing = 10;
                            }

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: 8,
                              ),
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                ),
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  return MenuItem(
                                    context: context,
                                    imagePath: item['imagePath']?.toString() ?? '',
                                    text: item['name']?.toString() ?? '',
                                    code: item['foodCode']?.toString() ?? '',
                                    price: item['price']?.toString() ?? '0',
                                    imagerecordId: item['id'] ?? item['name'] ?? 'unknown',
                                    stocks: item['stocks']?.toString() ?? 'N/A',
                                    baseVariant: item['baseVariant']?.toString(),
                                    variants: item['variants'] as List<dynamic>?,
                                    onAdd: (name, price, quantity, unit, unitQty) {
                                      audioPlayer.play(AssetSource('sounds/beep.mp3'));

                                      setState(() {
                                        isTapped = true;

                                        final displayName = unit.isNotEmpty ? '$name ($unitQty $unit)' : name;

                                        final parsedPrice = (double.tryParse(price) ?? 0).toInt();

                                        // 🔍 Check if same item + same unit already exists
                                        final existingIndex = selectedItemsDetails.indexWhere(
                                          (element) =>
                                              element['name'] == displayName && element['price'] == parsedPrice,
                                        );

                                        if (existingIndex != -1) {
                                          selectedItemsDetails[existingIndex]['quantity'] += quantity;
                                        } else {
                                          selectedItemsDetails.add({
                                            'name': displayName,
                                            'price': parsedPrice,
                                            'quantity': quantity,
                                            'unit': unit,
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
                            );
                          }),
                        ),
                        printprovider.posts.isEmpty
                            ? const SizedBox()
                            : BillCart(
                                adminUid: adminUid,
                                phoneNo: widget.phoneNo,
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
                                    onSave: () {
                                      _saveDataAndNavigate();
                                      printprovider.clearCart();
                                      nameController.clear();
                                      mobileController.clear();
                                      developer.log('Order saved for ${nameController.text}, ${mobileController.text}',
                                          name: 'ProductDashBoard');
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
      ),
    );
  }

  Widget billCountContainer() {
    final printprovider = Provider.of<PrintProvider>(
      context,
    );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                    Text(
                      ' My Cart',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'tabfont',
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedItemsDetails.length} Items',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Container(
            height: MediaQuery.of(context).size.height * 0.15,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              controller: _listScrollController,
              itemCount: printprovider.posts.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: appbar1,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedItemsDetails[index]['name'],
                              style: const TextStyle(
                                overflow: TextOverflow.ellipsis,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${selectedItemsDetails[index]['price']} × ${selectedItemsDetails[index]['quantity']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quantity Controls
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (selectedItemsDetails[index]['quantity'] > 1) {
                                    // Just decrease quantity
                                    selectedItemsDetails[index]['quantity']--;
                                    subtotal -= selectedItemsDetails[index]['price'];
                                  } else {
                                    // Quantity is 1 → remove item entirely
                                    subtotal -= selectedItemsDetails[index]['price'];
                                    selectedItemsDetails.removeAt(index);
                                  }
                                  // Update provider
                                  printprovider.additem(selectedItemsDetails, subtotal);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.remove,
                                  color: appbar1,
                                  size: 18,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "${selectedItemsDetails[index]['quantity']}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedItemsDetails[index]['quantity']++;
                                  subtotal += selectedItemsDetails[index]['price'];
                                  printprovider.additem(
                                    selectedItemsDetails,
                                    subtotal,
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.add,
                                  color: appbar1,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete Button
                      InkWell(
                        onTap: () {
                          setState(() {
                            subtotal -= selectedItemsDetails[index]['price'] * selectedItemsDetails[index]['quantity'];
                            selectedItemsDetails.removeAt(index);
                            printprovider.additem(selectedItemsDetails, subtotal);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer with Total and Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "₹$subtotal",
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.bookmark_outline,
                          color: appbar1,
                          size: 25,
                        ),
                        onPressed: () async {
                          // showSaveOrderBottomSheet(
                          //   context: context,
                          //   formKey: _formKey,
                          //   nameController: userNameController,
                          //   mobileController: mobileController,
                          //   itemCount: selectedItemsDetails.length,
                          //   totalAmount: subtotal,
                          //   primaryColor: primaryColor,
                          //   onSave: () {
                          //     _saveDataAndNavigate();
                          //     printprovider.clearCart();
                          //     userNameController.clear();
                          //   },
                          // );
                          showSaveOrderBottomSheet(
                            context: context,
                            formKey: _formKey,
                            nameController: nameController,
                            mobileController: mobileController,
                            addressController: addressController,
                            gstController: gstController,
                            itemCount: selectedItemsDetails.length,
                            totalAmount: subtotal,
                            primaryColor: primaryColor,
                            onSave: () {
                              _saveDataAndNavigate();
                              printprovider.clearCart();
                              nameController.clear();
                              mobileController.clear();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appbar1, appbar1.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: appbar1.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Consumer<PrintProvider>(
                        builder: (context, printProvider, child) {
                          return IconButton(
                            icon: Icon(
                              Icons.print,
                              color: printProvider.isConnected ? Colors.green : Colors.white,
                              size: 24,
                            ),
                            onPressed: () async {
                              // Check if printer is connected
                              if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
                                // Show connection dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => const PrinterConnectionDialog(),
                                );

                                // Show info message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please connect a printer first'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              // Check if there are items to print
                              if (selectedItemsDetails.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No items to print'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              // Show loading indicator
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              try {
                                // Fetch shop data
                                final doc = await FirebaseFirestore.instance
                                    .collection('AllAdmins')
                                    .doc(adminUid)
                                    .collection('customer')
                                    .doc(widget.phoneNo)
                                    .get();

                                String shopName = 'N/A';
                                String contact = 'N/A';
                                String address = 'N/A';

                                if (doc.exists) {
                                  final data = doc.data();
                                  if (data != null) {
                                    shopName = data['shopName'] ?? 'N/A';
                                    contact = data['contact'] ?? 'N/A';
                                    address = data['address'] ?? 'N/A';
                                  }
                                }

                                // Close loading dialog
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }

                                // Print receipt directly (also saves bill)
                                await DirectPrintHelper.printReceipt(
                                  adminUid: widget.phoneNo,
                                  context: context,
                                  printer: printProvider.selectedPrinter!,
                                  paperSize: printProvider.selectedPaperSize,
                                  items: selectedItemsDetails,
                                  total: subtotal,
                                  shopName: shopName,
                                  contact: contact,
                                  address: address,
                                  saveBill: true, // Save bill since it's not saved elsewhere
                                );

                                printprovider.clearCart();
                              } catch (e) {
                                // Close loading dialog
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }

                                debugPrint('Error printing receipt: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Printing failed: $e'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveDataAndNavigate() async {
    final userMap = {
      'userName': nameController.text,
      'phoneNumber': mobileController.text,
      'details': _encodeDetails(selectedItemsDetails),
      'totalAmount': subtotal,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Save data to Hive
    final box = await Hive.openBox('userBox');
    box.add(userMap);
    nameController.clear();
    mobileController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UsersScreen(),
      ),
    );
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
    search.dispose();
    nameController.dispose();
    mobileController.dispose();
    _listScrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}
