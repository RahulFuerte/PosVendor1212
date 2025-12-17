import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/view/home/edit_billReceipt.dart';
import 'package:pos/view/home/hiveScreen.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/sales_reportScreen.dart';
import 'package:pos/view/login/inception.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/network_error_handler.dart';
import 'package:pos/view/tab_screen/view-model/backend/price_utils.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:pos/view/tab_screen/view-model/widgets/offline_status_indicator.dart';
import 'package:pos/view/tab_screen/view-model/widgets/offline_status_banner.dart' as banner;
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tab_screen/view-model/widgets/show_save_order_bottom_sheet.dart';

class ProductDashBoard extends StatefulWidget {
  final String phoneNo;

  const ProductDashBoard({required this.phoneNo, Key? key}) : super(key: key);

  @override
  State<ProductDashBoard> createState() => _ProductDashBoardState();
}

class _ProductDashBoardState extends State<ProductDashBoard> {
  TextEditingController search = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController userNameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    foodItemsFuture = fetchFoodItems();
    fetchUserData();
  }

  Future<String> fetchAdminUid() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('AllCustomer').doc(widget.phoneNo).get();

      final String? adminUid = snapshot.data()?['adminUid'];

      setState(() {
        this.adminUid = adminUid ?? 'Admin UID not found';
      });

      return adminUid ?? 'Admin UID not found';
    } catch (e) {
      if (e is SocketException) {
        developer.log('Network error fetching adminUid: ${e.message}', name: 'ProductDashBoard');
        // Try to get cached adminUid from local storage if available
        try {
          final box = await Hive.openBox('userCache');
          final cachedAdminUid = box.get('adminUid_${widget.phoneNo}');
          if (cachedAdminUid != null) {
            developer.log('Using cached adminUid: $cachedAdminUid', name: 'ProductDashBoard');
            setState(() {
              this.adminUid = cachedAdminUid;
            });
            return cachedAdminUid;
          }
        } catch (cacheError) {
          developer.log('Error accessing cache: $cacheError', name: 'ProductDashBoard');
        }
        
        setState(() {
          this.adminUid = 'Offline - Admin UID unavailable';
        });
        return 'Offline - Admin UID unavailable';
      } else {
        developer.log('Error fetching adminUid: $e', name: 'ProductDashBoard');
        return 'Error fetching adminUid';
      }
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

      bool isHotValue(dynamic v) {
        if (v == null) return false;
        if (v is bool) return v;
        if (v is int) return v == 1;
        if (v is String) {
          final lower = v.toLowerCase();
          return lower == 'true' || lower == '1' || lower == 'yes' || lower == 'y';
        }
        return false;
      }

      // Filter for hot food items (supporting multiple key names & types)
      final List<Map<String, dynamic>> hotItems = allItems.where((item) {
        final dynamic raw = item['is_hot'] ?? item['isHot'];
        final bool isHot = isHotValue(raw);
        // Debug each item decision (you can remove or comment out this line later)
        developer.log('Checking item "${item['name'] ?? item['id'] ?? 'unknown'}": raw=$raw (${raw?.runtimeType}), isHot=$isHot', name: 'ProductDashBoard');
        return isHot;
      }).map((item) {
        return {
          'id': item['id'] ?? item['name'],
          'name': item['name'] ?? 'N/A',
          'price': PriceUtils.safePriceToString(item['price']),
          'imagePath': item['image_path'] ?? item['imagePath'] ?? 'N/A',
          'description': item['description'] ?? 'N/A',
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

  Future<void> fetchUserData() async {
    final phoneNo = widget.phoneNo;
    setState(() {
      isLoading = true; // Set isLoading to true before fetching data.
    });

    try {
      final DocumentSnapshot doc = await firestore.collection('AllCustomer').doc(phoneNo).get();
      developer.log('Fetched Data: ${doc.data()}', name: 'ProductDashBoard');
      developer.log('Phone Number: $phoneNo', name: 'ProductDashBoard');

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          userData = data;
        });

        // Cache the adminUid for offline use
        try {
          final box = await Hive.openBox('userCache');
          if (data['adminUid'] != null) {
            await box.put('adminUid_$phoneNo', data['adminUid']);
          }
          await box.put('userData_$phoneNo', data);
        } catch (cacheError) {
          developer.log('Error caching user data: $cacheError', name: 'ProductDashBoard');
        }
      } else {
        developer.log('Vendor document not found', name: 'ProductDashBoard');
        // Try to load cached data
        await _loadCachedUserData(phoneNo);
      }
    } catch (e) {
      NetworkErrorHandler.logNetworkError(e, 'ProductDashBoard', 'fetchUserData');
      // Load cached data when offline
      await _loadCachedUserData(phoneNo);
      // Show user-friendly message for network errors
      if (mounted && NetworkErrorHandler.isNetworkError(e)) {
        NetworkErrorHandler.showNetworkErrorSnackBar(context, e);
      }
    } finally {
      setState(() {
        isLoading = false; // Set isLoading to false after fetching data.
      });
    }
  }

  Future<void> _loadCachedUserData(String phoneNo) async {
    try {
      final box = await Hive.openBox('userCache');
      final cachedUserData = box.get('userData_$phoneNo');
      if (cachedUserData != null) {
        developer.log('Loading cached user data', name: 'ProductDashBoard');
        setState(() {
          userData = Map<String, dynamic>.from(cachedUserData);
        });
      } else {
        // Set default values if no cache available
        setState(() {
          userData = {
            'name': 'User',
            'phoneNumber': phoneNo,
          };
        });
      }
    } catch (e) {
      developer.log('Error loading cached user data: $e', name: 'ProductDashBoard');
      // Set minimal default values
      setState(() {
        userData = {
          'name': 'User',
          'phoneNumber': phoneNo,
        };
      });
    }
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

    return WillPopScope(
      onWillPop: () async {
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
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: white,
          elevation: 0,
          title: const Row(
            children: [
              SizedBox(width: 8),
              OfflineStatusIndicator(showWhenOnline: true),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSearchExpanded ? MediaQuery.of(context).size.width * 0.75 : 50,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isSearchExpanded ? Icons.search : Icons.search,
                        color: primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          isSearchExpanded = !isSearchExpanded;
                          if (!isSearchExpanded) {
                            search1 = '';
                            FocusScope.of(context).unfocus();
                          }
                        });
                      },
                    ),
                    if (isSearchExpanded)
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          onChanged: (value) {
                            search1 = value;
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search food items...',
                            hintStyle: TextStyle(
                              color: Colors.grey.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    if (isSearchExpanded)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            search1 = '';
                            isSearchExpanded = !isSearchExpanded;
                            if (!isSearchExpanded) {
                              FocusScope.of(context).unfocus();
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: primaryColor,
                ),
                child: Row(
                  children: [
                    Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(75),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(75),
                        child: Image.network(
                          'https://img.freepik.com/premium-vector/businessman-avatar-cartoon-character-profile_18591-50585.jpg?w=360',
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: primaryColor,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Handle network errors gracefully
                            if (error is SocketException) {
                              developer.log('Network error loading avatar: ${error.message}', name: 'ProductDashBoard');
                            } else {
                              developer.log('Error loading avatar: $error', name: 'ProductDashBoard');
                            }
                            return Container(
                              color: primaryColor,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${userData['name']}',
                            style: const TextStyle(
                              fontFamily: 'tabfont',
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 17,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${userData['phoneNumber']}',
                            style: const TextStyle(
                              fontFamily: 'fontmain',
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Printer Connection Status
              Consumer<PrintProvider>(
                builder: (context, printProvider, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: printProvider.isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: printProvider.isConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          printProvider.isConnected ? Icons.check_circle : Icons.print_disabled,
                          color: printProvider.isConnected ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                printProvider.isConnected ? 'Printer Connected' : 'Printer Not Connected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: printProvider.isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                                ),
                              ),
                              if (printProvider.isConnected && printProvider.selectedPrinter != null)
                                Text(
                                  printProvider.selectedPrinter!.deviceName ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Connect/Disconnect Printer
              Consumer<PrintProvider>(
                builder: (context, printProvider, child) {
                  return ListTile(
                    leading: Icon(
                      printProvider.isConnected ? Icons.link_off : Icons.link,
                      color: printProvider.isConnected ? Colors.red : Colors.blue,
                    ),
                    title: Text(
                      printProvider.isConnected ? 'Disconnect Printer' : 'Connect Printer',
                    ),
                    onTap: () async {
                      if (printProvider.isConnected) {
                        // Disconnect printer
                        if (printProvider.selectedPrinter != null) {
                          await PrinterManager.instance.disconnect(
                            type: printProvider.selectedPrinter!.typePrinter,
                          );
                          printProvider.disconnectPrinter();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Printer disconnected'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } else {
                        // Show connection dialog
                        Navigator.pop(context); // Close drawer
                        showDialog(
                          context: context,
                          builder: (context) => const PrinterConnectionDialog(),
                        );
                      }
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(MdiIcons.chartBar),
                title: const Text('Sales Report'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SalesReportScreen(
                        adminUid: widget.phoneNo,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt),
                title: const Text('Edit bill Receipt'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditBillReceiptScreen(
                        AdminUid: adminUid,
                        phoneNo: widget.phoneNo,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log Out'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext) {
                      return Dialog(
                          // backgroundColor: Colors.amber.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)), //this right here
                          child: SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Text(
                                    "Are you sure ?",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                        child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text(
                                          "Logout",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        onPressed: () async {
                                          SharedPreferences prefs = await SharedPreferences.getInstance();
                                          await prefs.setBool('isLogged', false);
                                          FirebaseAuth.instance.signOut();
                                          Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const Inception(),
                                              ));
                                        },
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ));
                    },
                  );
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            banner.OfflineStatusBanner(adminUid: adminUid),
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FutureBuilder(
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
                        List<Map<String, dynamic>> filteredItems = foodItemsList.where((item) => item['name'].toString().toLowerCase().contains(search1.toLowerCase())).toList();

                        return Container(
                          height: double.infinity,
                          width: double.infinity,
                          color: Colors.green[50],
                          child: Column(
                            children: [
                              printprovider.posts.isEmpty ? const SizedBox() : billCountContainer(),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.78, // Slightly taller to prevent overflow
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: filteredItems.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      return GestureDetector(
                                        onTap: () {
                                          audioPlayer.play(AssetSource('sounds/beep.mp3'));
                                          setState(() {
                                            isTapped = true;
                                            selectedItemName = item['name'] ?? '';
                                            selectedItemPrice = PriceUtils.safeParseInt(item['price']);

                                            int existingIndex = selectedItemsDetails.indexWhere(
                                              (element) => element['name'] == selectedItemName && element['price'] == selectedItemPrice,
                                            );

                                            if (existingIndex != -1) {
                                              selectedItemsDetails[existingIndex]['quantity'] += 1;
                                            } else {
                                              selectedItemsDetails.add({
                                                'name': selectedItemName,
                                                'price': selectedItemPrice,
                                                'quantity': 1,
                                              });
                                            }
                                            subtotal += selectedItemPrice;
                                            printprovider.additem(selectedItemsDetails, subtotal);

                                            // Safely scroll to bottom with proper checks
                                            if (_listScrollController.hasClients && _listScrollController.position.hasContentDimensions) {
                                              try {
                                                _listScrollController.jumpTo(
                                                  _listScrollController.position.maxScrollExtent,
                                                );
                                              } catch (e) {
                                                developer.log('ScrollController error: $e', name: 'ProductDashBoard');
                                              }
                                            }
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.2),
                                                spreadRadius: 1,
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              )
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Image section - flexible height
                                              Expanded(
                                                flex: 3,
                                                child: Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(16),
                                                        topRight: Radius.circular(16),
                                                      ),
                                                      child: CachedBlobImage(
                                                        imageUrl: item['imagePath'],
                                                        tableName: 'food_items',
                                                        recordId: item['id'] ?? item['name'] ?? 'unknown',
                                                        height: double.infinity,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        placeholder: Container(
                                                          color: Colors.grey[200],
                                                          child: const Center(
                                                            child: CircularProgressIndicator(
                                                              color: primaryColor,
                                                            ),
                                                          ),
                                                        ),
                                                        errorWidget: Container(
                                                          color: Colors.grey[200],
                                                          child: const Icon(Icons.error),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 3,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(10),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.1),
                                                              blurRadius: 4,
                                                            )
                                                          ],
                                                        ),
                                                        child: Text(
                                                          "₹${item['price']}",
                                                          style: const TextStyle(
                                                            color: primaryColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Content section - flexible height
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        item['name'],
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'fontmain',
                                                          color: Colors.black87,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 14,
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.symmetric(
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(color: appbar1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              Icons.shopping_cart,
                                                              color: appbar1,
                                                              size: 16,
                                                            ),
                                                            Text(
                                                              " Add to cart",
                                                              style: TextStyle(
                                                                fontFamily: 'tabfont',
                                                                color: appbar1,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
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
                          showSaveOrderBottomSheet(
                            context: context,
                            formKey: _formKey,
                            nameController: userNameController,
                            mobileController: mobileController,
                            itemCount: selectedItemsDetails.length,
                            totalAmount: subtotal,
                            primaryColor: primaryColor,
                            onSave: () {
                              _saveDataAndNavigate();
                              printprovider.clearCart();
                              userNameController.clear();
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
                                final doc = await FirebaseFirestore.instance.collection('AllAdmins').doc(adminUid).collection('customer').doc(widget.phoneNo).get();

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

                                // Print receipt directly
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
      'userName': userNameController.text,
      'mobileNo': mobileController.text,
      'details': _encodeDetails(selectedItemsDetails),
      'totalAmount': subtotal,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Save data to Hive
    final box = await Hive.openBox('userBox');
    box.add(userMap);
    userNameController.clear();
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
    userNameController.dispose();
    mobileController.dispose();
    _listScrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}