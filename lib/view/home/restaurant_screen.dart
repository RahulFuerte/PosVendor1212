import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import '../tab_screen/view-model/backend/sqlite_helper.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/view/home/usersDataScreen.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:provider/provider.dart';

import '../tab_screen/view-model/backend/complete_offline_data_manager.dart';
import '../tab_screen/view-model/backend/connection_monitor.dart';
import '../tab_screen/view-model/backend/data_preloading_coordinator.dart';
import '../tab_screen/view-model/backend/offline_bill_manager.dart';
import '../tab_screen/view-model/backend/smart_database_service.dart';
import '../tab_screen/view-model/widgets/cached_blob_image.dart';
import '../tab_screen/view-model/widgets/show_save_order_bottom_sheet.dart';
import '../tab_screen/view-model/widgets/bill_count/bill_cart_widget.dart';
import 'print_provider.dart';

class RestaurantScreen extends StatefulWidget {
  final String phoneNo;
  const RestaurantScreen({required this.phoneNo, Key? key}) : super(key: key);

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
  String selectedDepartment = '';
  bool isTapped = false;
  Map<String, int> itemPriceCount = {};
  double totalPrice = 0.0;
  bool isLoading = true;
  bool isContainerVisible = true;
  late Future<List<Map<String, dynamic>>> foodDepartmentsFuture;
  late Future<List<Map<String, dynamic>>> foodItemsFuture;
  List<Map<String, dynamic>> selectedItemsDetails = [];
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController userPhoneController = TextEditingController();
  final ScrollController _gridViewController = ScrollController();

  // Offline functionality
  final CompleteOfflineDataManager _offlineDataManager =
      CompleteOfflineDataManager();
  final DataPreloadingCoordinator _preloadingCoordinator =
      DataPreloadingCoordinator();
  final SmartDatabaseService _smartDB = SmartDatabaseService();
  final OfflineBillManager _offlineBillManager = OfflineBillManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  StreamSubscription<bool>? _connectionSubscription;
  bool _isOnline = true;
  int _pendingBillsCount = 0;

  DateTime? currentBackPressTime;

  @override
  void initState() {
    super.initState();
    _initializeAll();
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

      _connectionSubscription =
          _connectionMonitor.connectivityStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isOnline = isConnected;
          });
        }
        if (_isOnline) {
          _syncPendingBills();
        }
      });

      developer.log('Connection status initialized: $_isOnline',
          name: 'RestaurantScreen');
    } catch (e) {
      developer.log('Error setting up connection listener: $e',
          name: 'RestaurantScreen');
      _isOnline = false; // Assume offline on error
    }
  }

  Future<void> _initializeSmartDatabase() async {
    try {
      await _smartDB.initialize();
      developer.log('Smart Database Service initialized successfully',
          name: 'RestaurantScreen');
    } catch (e) {
      developer.log('Error initializing Smart Database Service: $e',
          name: 'RestaurantScreen');
    }
  }

  Future<void> _initializeOfflineData() async {
    try {
      await _offlineDataManager.initialize();
      await _preloadingCoordinator.initialize();
      await _connectionMonitor.initialize();

      final adminUid = await fetchAdminUid();
      if (adminUid.isNotEmpty &&
          !adminUid.contains('Error') &&
          !adminUid.contains('Offline')) {
        _preloadingCoordinator.setUserPreloadingStrategy(
          adminUid,
          PreloadingStrategy(priority: PreloadingPriority.medium),
        );
        _preloadingCoordinator.triggerImmediatePreloading(adminUid);
      }
    } catch (e) {
      developer.log('Error initializing offline data: $e',
          name: 'RestaurantScreen');
    }
  }

  Future<void> _initializeOfflineBillManager() async {
    try {
      await _offlineBillManager.initialize();
      _updatePendingBillsCount();
    } catch (e) {
      developer.log('Error initializing offline bill manager: $e',
          name: 'RestaurantScreen');
    }
  }

  Future<void> showSaveOrderBottomSheet({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController mobileController,
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

  // Connection listener is now setup in _setupConnectionListenerAsync()

  Future<void> _updatePendingBillsCount() async {
    if (adminUid.isNotEmpty &&
        !adminUid.contains('Error') &&
        !adminUid.contains('not found')) {
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
      }
    } catch (e) {
      print('Error initializing food items: $e');
    }
  }

  Future<String> fetchAdminUid() async {
    // Use SmartDatabaseService which handles online/offline automatically
    try {
      // Try Firebase with short timeout - SmartDatabaseService handles caching
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
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
          developer.log('Error caching adminUid in SQLite: $cacheError',
              name: 'RestaurantScreen');
        }

        setState(() {
          this.adminUid = fetchedAdminUid;
        });
        return fetchedAdminUid;
      }

      // If Firebase returned null, try SQLite cache
      return await _getCachedAdminUid();
    } catch (e) {
      developer.log('Error fetching adminUid: $e', name: 'RestaurantScreen');
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
        developer.log('Using cached adminUid from SQLite: $cachedAdminUid',
            name: 'RestaurantScreen');
        setState(() {
          this.adminUid = cachedAdminUid;
        });
        return cachedAdminUid;
      }

      // Last resort: use phoneNo as adminUid (common pattern in this app)
      developer.log('No cached adminUid found, using phoneNo as fallback',
          name: 'RestaurantScreen');
      setState(() {
        this.adminUid = widget.phoneNo;
      });
      return widget.phoneNo;
    } catch (e) {
      developer.log('Error getting cached adminUid from SQLite: $e',
          name: 'RestaurantScreen');
      // Ultimate fallback: use phoneNo
      setState(() {
        this.adminUid = widget.phoneNo;
      });
      return widget.phoneNo;
    }
  }

  /// Fetch departments using SmartDatabaseService (handles online/offline automatically)
  Future<List<Map<String, dynamic>>> fetchFoodDepartment() async {
    try {
      final String fetchedAdminUid = await fetchAdminUid();

      // Use SmartDatabaseService - it handles online/offline automatically via SQLite
      final rawDepartments = await _smartDB.getDepartments(fetchedAdminUid);

      // Map SQLite field names to UI expected names
      final departments = rawDepartments
          .map((dept) => {
                'id': dept['id'] ?? dept['name'],
                'name': dept['name'] ?? 'N/A',
                'imageUrl': dept['imageUrl'] ??
                    dept['image_url'] ??
                    dept['imageurl'] ??
                    'N/A',
                'status': dept['status'] ?? 'Active',
              })
          .toList();

      developer.log('Fetched ${departments.length} departments via SmartDB',
          name: 'RestaurantScreen');
      return departments;
    } catch (e) {
      developer.log('Error fetching departments: $e', name: 'RestaurantScreen');
      return [];
    }
  }

  /// Fetch food items using SmartDatabaseService (handles online/offline automatically)
  Future<List<Map<String, dynamic>>> fetchFoodItems(String department) async {
    try {
      final String currentAdminUid =
          adminUid.isNotEmpty ? adminUid : await fetchAdminUid();
      final String deptToFetch = department.isEmpty
          ? (selectedDepartment.isEmpty ? 'Pizza' : selectedDepartment)
          : department;

      // Use SmartDatabaseService - it handles online/offline automatically via SQLite
      final rawItems =
          await _smartDB.getFoodItems(currentAdminUid, department: deptToFetch);

      // Map SQLite field names to UI expected names
      final items = rawItems
          .map((item) => {
                'id': item['id'] ?? item['name'],
                'name': item['name'] ?? 'N/A',
                'price': item['price']?.toString() ?? '0',
                'imagePath': item['imagePath'] ??
                    item['image_path'] ??
                    item['imagepath'] ??
                    'N/A',
                'foodCode': item['foodCode'] ??
                    item['food_code'] ??
                    item['foodcode'] ??
                    'N/A',
                'department': item['department'] ?? 'N/A',
                'stocks': item['stocks'] ?? 'N/A',
              })
          .toList();

      setState(() {
        isLoading = false;
      });

      developer.log(
          'Fetched ${items.length} food items for $deptToFetch via SmartDB',
          name: 'RestaurantScreen');
      return items;
    } catch (e) {
      developer.log('Error fetching food items: $e', name: 'RestaurantScreen');
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
        color: _isOnline
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
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
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _isOnline ? Colors.green : Colors.orange,
            ),
          ),
          if (_pendingBillsCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_pendingBillsCount pending',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printprovider = Provider.of<PrintProvider>(context);
    selectedItemsDetails = printprovider.posts;
    subtotal = printprovider.total;

    return WillPopScope(
      onWillPop: () async {
        DateTime now = DateTime.now();
        if (currentBackPressTime == null ||
            now.difference(currentBackPressTime!) >
                const Duration(seconds: 2)) {
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
          actions: [
            _buildConnectionStatusIndicator(),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => UsersScreen()));
              },
              icon: const Icon(Icons.save),
            ),
          ],
          leading: IconButton(
            icon: isContainerVisible
                ? Icon(MdiIcons.fullscreen)
                : Icon(MdiIcons.fullscreenExit),
            onPressed: () {
              setState(() {
                isContainerVisible = !isContainerVisible;
                _gridViewController.jumpTo(0.0);
              });
            },
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Restaurants',
            style: TextStyle(
                color: Colors.black, fontFamily: 'tabfont', fontSize: 19),
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: appbar1))
            : Container(
                color: Colors.grey.withOpacity(0.1),
                width: double.infinity,
                height: double.infinity,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isContainerVisible
                          ? MediaQuery.of(context).size.width * 0.21
                          : 0,
                      child: Container(
                        decoration: const BoxDecoration(color: white),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: foodDepartmentsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                  child: Text('Error: ${snapshot.error}'));
                            } else {
                              List<Map<String, dynamic>> departments =
                                  snapshot.data ?? [];
                              return ListView.builder(
                                itemCount: departments.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 7),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          currentCategoryIndex = index;
                                          selectedDepartment =
                                              departments[index]['name'] ?? '';
                                        });
                                        foodItemsFuture =
                                            fetchFoodItems(selectedDepartment);
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            children: [
                                              Stack(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 300),
                                                    margin:
                                                        const EdgeInsets.all(5),
                                                    height: 60,
                                                    width: 60,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          currentCategoryIndex ==
                                                                  index
                                                              ? const Color
                                                                  .fromARGB(106,
                                                                  133, 238, 187)
                                                              : Colors.blueGrey
                                                                  .shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 5,
                                                    left: 6,
                                                    right: 4,
                                                    child: AnimatedContainer(
                                                      height:
                                                          currentCategoryIndex ==
                                                                  index
                                                              ? 65
                                                              : 55,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(55),
                                                      ),
                                                      duration: const Duration(
                                                          milliseconds: 400),
                                                      child: CachedBlobImage(
                                                        imageUrl:
                                                            departments[index]
                                                                ['imageUrl'],
                                                        tableName:
                                                            'departments',
                                                        recordId: departments[
                                                                index]['id'] ??
                                                            departments[index]
                                                                ['name'] ??
                                                            departments[index]
                                                                ['unknown'],
                                                        width: 50,
                                                        height: 50,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(100),
                                                        placeholder:
                                                            const CircularProgressIndicator(),
                                                      ),

                                                      //  ImageNetwork(
                                                      //   onTap: () {
                                                      //     setState(() {
                                                      //       currentCategoryIndex =
                                                      //           index;
                                                      //       selectedDepartment =
                                                      //           departments[index]
                                                      //                   [
                                                      //                   'name'] ??
                                                      //               '';
                                                      //     });
                                                      //     foodItemsFuture =
                                                      //         fetchFoodItems(
                                                      //             selectedDepartment);
                                                      //   },
                                                      //   image:
                                                      //       departments[index]
                                                      //           ['imageUrl'],
                                                      //   imageCache:
                                                      //       CachedNetworkImageProvider(
                                                      //     departments[index]
                                                      //         ['imageUrl'],
                                                      //   ),
                                                      //   height: 40,
                                                      //   width: 30,
                                                      //   borderRadius:
                                                      //       BorderRadius
                                                      //           .circular(100),
                                                      //   fitWeb: BoxFitWeb.cover,
                                                      // ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                departments[index]['name'] ??
                                                    'N/A',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'fontmain',
                                                  fontWeight:
                                                      currentCategoryIndex ==
                                                              index
                                                          ? FontWeight.bold
                                                          : FontWeight.w400,
                                                  color: currentCategoryIndex ==
                                                          index
                                                      ? Colors.black
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            height: 100,
                                            width: 5,
                                            decoration: BoxDecoration(
                                              color:
                                                  currentCategoryIndex == index
                                                      ? appbar1
                                                      : Colors.white,
                                              borderRadius:
                                                  const BorderRadius.only(
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
                      child: Column(
                        children: [
                          printprovider.posts.isNotEmpty
                              ? BillCart(
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
                                      nameController: userNameController,
                                      mobileController: userPhoneController,
                                      itemCount: selectedItemsDetails.length,
                                      totalAmount: subtotal,
                                      primaryColor: primaryColor,
                                      onSave: () {
                                        _saveDataAndNavigate();
                                        printprovider.clearCart();
                                        userNameController.clear();
                                        userPhoneController.clear();
                                      },
                                    );
                                  },
                                )
                              : const SizedBox(),
                          Expanded(
                            child: Container(
                              child: FutureBuilder(
                                future: foodItemsFuture,
                                builder: (context,
                                    AsyncSnapshot<List<Map<String, dynamic>>>
                                        snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                          color: primaryColor),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Center(
                                        child: Text('Error: ${snapshot.error}'));
                                  } else {
                                    List<Map<String, dynamic>> foodItemsList =
                                        snapshot.data ?? [];
                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        int crossAxisCount;
                                        double childAspectRatio;
                                        double horizontalPadding;
                                        double spacing;
                                        double availableWidth =
                                            constraints.maxWidth;
                              
                                        if (availableWidth > 1400) {
                                          crossAxisCount =
                                              isContainerVisible ? 4 : 5;
                                          childAspectRatio = 0.80;
                                          horizontalPadding = 16;
                                          spacing = 16;
                                        } else if (availableWidth > 1000) {
                                          crossAxisCount =
                                              isContainerVisible ? 3 : 4;
                                          childAspectRatio = 0.78;
                                          horizontalPadding = 12;
                                          spacing = 12;
                                        } else if (availableWidth > 700) {
                                          crossAxisCount =
                                              isContainerVisible ? 2 : 3;
                                          childAspectRatio = 0.75;
                                          horizontalPadding = 10;
                                          spacing = 10;
                                        } else if (availableWidth > 500) {
                                          crossAxisCount = 2;
                                          childAspectRatio = 0.72;
                                          horizontalPadding = 8;
                                          spacing = 8;
                                        } else {
                                          crossAxisCount = isContainerVisible ? 1 : 2;
                                          childAspectRatio = 0.70;
                                          horizontalPadding = 8;
                                          spacing = 8;
                                        }
                              
                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: horizontalPadding,
                                            vertical: 8,
                                          ),
                                          child: GridView.builder(
                                            controller: _gridViewController,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: crossAxisCount,
                                              childAspectRatio: childAspectRatio,
                                              crossAxisSpacing: spacing,
                                              mainAxisSpacing: spacing,
                                            ),
                                            itemCount: foodItemsList.length,
                                            itemBuilder: (context, index) {
                                              final item = foodItemsList[index];
                                              return GestureDetector(
                                                onTap: () {
                                                  audioPlayer.play(AssetSource(
                                                      'sounds/beep.mp3'));
                                                  setState(() {
                                                    isTapped = true;
                                                    selectedItemName =
                                                        item['name'] ?? '';
                                                    selectedItemPrice = (double.tryParse(
                                                        item['price']?.toString() ?? '0') ?? 0).toInt();
                              
                                                    int existingIndex =
                                                        selectedItemsDetails
                                                            .indexWhere(
                                                      (element) =>
                                                          element['name'] ==
                                                              selectedItemName &&
                                                          element['price'] ==
                                                              selectedItemPrice,
                                                    );
                              
                                                    if (existingIndex != -1) {
                                                      selectedItemsDetails[
                                                              existingIndex]
                                                          ['quantity'] += 1;
                                                    } else {
                                                      selectedItemsDetails.add({
                                                        'name': selectedItemName,
                                                        'price':
                                                            selectedItemPrice,
                                                        'quantity': 1,
                                                      });
                                                    }
                              
                                                    subtotal += selectedItemPrice;
                                                    printprovider.additem(
                                                        selectedItemsDetails,
                                                        subtotal);
                              
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback(
                                                            (_) {
                                                      if (_listScrollController
                                                          .hasClients) {
                                                        _listScrollController
                                                            .jumpTo(
                                                          _listScrollController
                                                              .position
                                                              .maxScrollExtent,
                                                        );
                                                      }
                                                    });
                                                  });
                                                },
                                                child: MenuItem(
                                                  context: context,
                                                  imagePath:
                                                      item['imagePath']?.toString() ?? '',
                                                  text: item['name']?.toString() ?? '',
                                                  code: item['foodCode']?.toString() ?? '',
                                                  price: item['price']?.toString() ?? '0',
                                                  stocks: item['stocks']?.toString() ?? 'N/A',
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      _saveDataAndNavigate();
                      printprovider.clearCart();
                      userNameController.clear();
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveDataAndNavigate() async {
    final userMap = {
      'phoneNumber': userPhoneController.text,
      'userName': userNameController.text,
      'details': selectedItemsDetails,
      'totalAmount': subtotal,
      
    };

    final box = await Hive.openBox('userBox');
    box.add(userMap);
    userNameController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UsersScreen()),
    );
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
