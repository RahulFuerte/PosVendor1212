// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;


// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



import 'package:hive/hive.dart';

import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:provider/provider.dart';


// Project imports:
import 'package:pos/core/error/network_error_handler.dart';

import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/view/home/navigation.dart';

import 'package:pos/data/providers/print_provider.dart';

import 'package:pos/view/home/screens/users_data_screen.dart';

import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

import 'package:pos/view/tab_screen/view-model/widgets/offline_status_indicator.dart';

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
        List<dynamic> parsedAddons = [];

        try {
          if (item['variants'] != null && item['variants'].toString().isNotEmpty) {
            parsedVariants = jsonDecode(item['variants'].toString());
          }
          if (item['addons'] != null && item['addons'].toString().isNotEmpty) {
            parsedAddons = jsonDecode(item['addons'].toString());
          }
        } catch (e) {
          parsedVariants = [];
        }
        return {
          'id': item['id'] ?? item['name'],
          'name': item['name'] ?? 'N/A',
          'price': item['price']?.toString() ?? '0',
          'price2': item['price2']?.toString() ?? '0',
          'price3': item['price3']?.toString() ?? '0',
          'priceType': item['priceType']?.toString(),
          'imagePath': item['imagePath'] ?? item['image_path'] ?? item['imagepath'] ?? 'N/A',
          'foodCode': item['foodCode'] ?? item['food_code'] ?? item['foodcode'] ?? 'N/A',
          'department': item['department'] ?? 'N/A',
          'stocks': item['stocks'] ?? 'N/A',
          'baseVariant': item['baseVariant'] ?? '',
          'variants': parsedVariants,
          'addons': parsedAddons,
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

    return Scaffold(
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
                            childAspectRatio = 0.7;
                            horizontalPadding = 8;
                            spacing = 8;
                          }

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 8,
                            ),
                            child: GridView.builder(
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
                                  imagerecordId: item['id']?.toString(),
                                  price: item['price']?.toString() ?? '0',
                                  price2: item['price2']?.toString() ?? '0',
                                  price3: item['price3']?.toString() ?? '0',
                                  priceType: item['priceType']?.toString() ?? 'Fixed',
                                  stocks: item['stocks']?.toString() ?? 'N/A',
                                  baseVariant: item['baseVariant']?.toString(),
                                  variants: item['variants'] as List<dynamic>?,
                                  addons: item['addons'] as List<dynamic>?,
                                  onAdd: (name, price, quantity, unit, unitQty, addOnList) {
                                    audioPlayer.play(AssetSource('sounds/beep.mp3'));

                                    setState(() {
                                      isTapped = true;

                                      final displayName = unit.isNotEmpty ? '$name ($unitQty $unit)' : name;

                                      final parsedPrice = (double.tryParse(price) ?? 0).toInt();

                                      // 🔍 Check if same item + same unit already exists
                                      final existingIndex = selectedItemsDetails.indexWhere(
                                        (element) => element['name'] == displayName && element['price'] == parsedPrice,
                                      );

                                      if (existingIndex != -1) {
                                        selectedItemsDetails[existingIndex]['quantity'] += quantity;
                                        selectedItemsDetails[existingIndex]['addons'] = addOnList;
                                      } else {
                                        selectedItemsDetails.add({
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
    );
  }

  // static Future<void> printReceipt({
  //   required BuildContext context,
  //   required BluetoothPrinter printer,
  //   required PaperSize paperSize,
  //   required List<Map<String, dynamic>> items,
  //   required double total,
  //   required String shopName,
  //   required String logoUrl,
  //   required String contact,
  //   required String address,
  //   required String adminUid,
  //   String? tableNumber,
  //   String? receiptNo, // Optional: pass existing receipt number, otherwise generate new one
  //   bool taxEnabled = false,
  //   double cgstPercent = 2.5,
  //   double sgstPercent = 2.5,
  //   bool saveBill = false, // Set to false by default since bill is usually saved before calling this
  // }) async {
  //   try {
  //     // Use provided receipt number or generate a new one
  //     final String finalReceiptNo = receiptNo ?? generateReceiptNumber();

  //     final profile = await CapabilityProfile.load(name: 'XP-N160I');
  //     final Generator generator = Generator(paperSize, profile);

  //     List<int> bytes = [];
  //     bytes += generator.setGlobalCodeTable('CP1252');

  //     // Paper configuration
  //     bool is58mm = paperSize == PaperSize.mm58;
  //     int totalCols = is58mm ? 31 : 48;
  //     String separator = '-' * totalCols;

  //     // Smart dynamic columns
  //     int desc = is58mm ? 12 : 22;
  //     int qty = is58mm ? 5 : 6;
  //     int rate = is58mm ? 6 : 8;
  //     int amt = is58mm ? 7 : 10;

  //     // Small font style
  //     const smallFontCenter = PosStyles(align: PosAlign.center);
  //     const smallFontLeft = PosStyles(align: PosAlign.left);

  //     String timeText = "Time: ${DateFormat('hh:mm a').format(DateTime.now())}";
  //     String receiptText = "Receipt No: $finalReceiptNo";

  //     // Calculate spaces needed between left and right
  //     int spaceCount = totalCols - timeText.length - receiptText.length;
  //     if (spaceCount < 1) spaceCount = 1;

  //     String line = timeText + ' ' * spaceCount + receiptText;

  //     // Header

  //     if (logoUrl.isNotEmpty) {
  //       final logoBytes = await _loadLogoForPrinter(logoUrl, generator);
  //       bytes += logoBytes;
  //       bytes += generator.feed(1); // small gap after logo
  //     }
  //     bytes += generator.emptyLines(1);
  //     bytes += generator.text(shopName, styles: const PosStyles(width: PosTextSize.size2, height: PosTextSize.size2));
  //     bytes += generator.text(address, styles: smallFontCenter);
  //     bytes += generator.text("Mob.No : $contact", styles: smallFontCenter);
  //     bytes += generator.text(separator, styles: smallFontLeft);
  //     // bytes += generator.text(
  //     //   "Date : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
  //     //   styles: smallFontLeft,
  //     // );
  //     // bytes += generator.text(
  //     //   line,
  //     //   styles: smallFontLeft,
  //     // );
  //     // bytes += generator.text(separator, styles: smallFontLeft);
  //     // // bytes += generator.text('RECEIPT', styles: smallFontCenter);
  //     // // bytes += generator.text('Receipt No: $finalReceiptNo', styles: smallFontCenter);

  //     // // // Table number (show N/A if not provided)
  //     // if (tableNumber != null && tableNumber.isNotEmpty) {
  //     //   bytes += generator.text(
  //     //     'Table No: $tableNumber ',
  //     //     styles: smallFontLeft,
  //     //   );
  //     // }

  //     // bytes += generator.text(separator, styles: smallFontLeft);

  //     // // Table header
  //     // bytes += generator.text(
  //     //   '${"Item".padRight(desc)}'
  //     //   '${"Qty".padLeft(qty)}'
  //     //   '${"Price".padLeft(rate)}'
  //     //   '${"Amt".padLeft(amt)}',
  //     //   styles: smallFontLeft,
  //     // );

  //     // Items
  //     // for (var item in items) {
  //     //   String name = item['name'].toString();
  //     //   if (name.length > desc) {
  //     //     name = name.substring(0, desc - 3) + "...";
  //     //   }

  //     //   int qtyValue = int.tryParse(item['quantity'].toString()) ?? 1;
  //     //   double rateValue = double.tryParse(item['price'].toString()) ?? 0;
  //     //   double amtValue = qtyValue * rateValue;

  //     //   bytes += generator.text(
  //     //     '${name.padRight(desc)}'
  //     //     '${qtyValue.toString().padLeft(qty)}'
  //     //     '${rateValue.toStringAsFixed(2).padLeft(rate)}'
  //     //     '${amtValue.toStringAsFixed(2).padLeft(amt)}',
  //     //     styles: smallFontLeft,
  //     //   );
  //     // }

  //     // Calculate totals
  //     double subtotal = total;
  //     double grandTotal = subtotal;

  //     // Subtotal
  //     // bytes += generator.text(separator, styles: smallFontLeft);
  //     // bytes += generator.text(
  //     //   'SUBTOTAL'.padRight(totalCols - 8) + subtotal.toStringAsFixed(2).padLeft(8),
  //     //   styles: smallFontLeft,
  //     // );

  //     // Only show tax if enabled
  //     // if (taxEnabled) {
  //     //   double cgst = subtotal * (cgstPercent / 100);
  //     //   double sgst = subtotal * (sgstPercent / 100);
  //     //   grandTotal = subtotal + cgst + sgst;

  //     //   // CGST
  //     //   bytes += generator.text(
  //     //     'CGST (${cgstPercent.toStringAsFixed(1)}%)'.padRight(totalCols - 8) + cgst.toStringAsFixed(2).padLeft(8),
  //     //     styles: smallFontLeft,
  //     //   );

  //     //   // SGST
  //     //   bytes += generator.text(
  //     //     'SGST (${sgstPercent.toStringAsFixed(1)}%)'.padRight(totalCols - 8) + sgst.toStringAsFixed(2).padLeft(8),
  //     //     styles: smallFontLeft,
  //     //   );
  //     // }

  //     // Grand Total
  //     // bytes += generator.text(separator, styles: smallFontLeft);
  //     // bytes += generator.text(
  //     //   'GRAND TOTAL'.padRight(totalCols - 8) + grandTotal.toStringAsFixed(2).padLeft(8),
  //     //   styles: smallFontLeft,
  //     // );

  //     // Footer
  //     // bytes += generator.text(separator, styles: smallFontLeft);
  //     // bytes += generator.text('Thank you! Visit Again', styles: smallFontCenter);
  //     // bytes += generator.cut();

  //     final isConnected = await isOnline();

  //     // Send to printer
  //     await PrinterManager.instance.send(
  //       type: printer.typePrinter,
  //       bytes: bytes,
  //     );

  //     // Only save bill if saveBill flag is true (to avoid duplicate saves)
  //     // When called from bill_cart_widget.dart, bill is already saved via SmartDatabaseService
  //     if (saveBill) {
  //       await saveBillToFirebase(
  //         adminUid: adminUid,
  //         receiptNo: finalReceiptNo,
  //         items: items,
  //         subTotal: subtotal,
  //       );
  //     }

  //     if (context.mounted) {
  //       final message = isConnected
  //           ? 'Receipt printed & saved online! Receipt No: $receiptNo'
  //           : 'Receipt printed & saved offline! Will sync when online. Receipt No: $receiptNo';

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(message),
  //           backgroundColor: isConnected ? Colors.green : Colors.orange,
  //           duration: const Duration(seconds: 4),
  //         ),
  //       );
  //       // ScaffoldMessenger.of(context).showSnackBar(
  //       //   SnackBar(
  //       //     content: Text('Receipt printed! Receipt No: $finalReceiptNo'),
  //       //     backgroundColor: Colors.green,
  //       //     duration: const Duration(seconds: 2),
  //       //   ),
  //       // );
  //     }
  //   } catch (e) {
  //     debugPrint("Printing error: $e");
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Printing failed: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

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
