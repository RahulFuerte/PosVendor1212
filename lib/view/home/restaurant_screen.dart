import 'dart:io';
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/view/home/hiveScreen.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/print_provider.dart';

import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/backend/network_error_handler.dart';
import 'package:pos/view/tab_screen/view-model/backend/price_utils.dart';
import 'package:pos/view/tab_screen/view-model/backend/complete_offline_data_manager.dart';
import 'package:pos/view/tab_screen/view-model/backend/offline_bill_manager.dart';
import 'package:pos/view/tab_screen/view-model/backend/connection_monitor.dart';
import 'package:pos/view/tab_screen/view-model/backend/data_preloading_coordinator.dart';
import 'package:pos/view/tab_screen/view-model/backend/smart_database_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';

import 'package:pos/view/tab_screen/view-model/widgets/offline_status_indicator.dart';
import 'package:pos/view/tab_screen/view-model/widgets/offline_status_banner.dart' as banner;
import 'package:pos/view/tab_screen/view-model/widgets/ui_performance_components.dart' as ui_perf;
import 'package:pos/view/tab_screen/view-model/widgets/enhanced_loading_states.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';


import 'package:provider/provider.dart';
import 'dart:async';


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
  final TextEditingController _searchController = TextEditingController();
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  final DataPreloadingCoordinator _preloadingCoordinator = DataPreloadingCoordinator();
  final SmartDatabaseService _smartDB = SmartDatabaseService();
  
  // Enhanced offline functionality
  List<Map<String, dynamic>> _allFoodItems = [];
  List<Map<String, dynamic>> _filteredFoodItems = [];
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  DateTime? currentBackPressTime;
  final OfflineBillManager _offlineBillManager = OfflineBillManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  final ScrollController _gridViewController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _initializeSmartDatabase();
    _initializeOfflineData();
    _initializeOfflineBillManager();
    _setupSearchListener();
    foodDepartmentsFuture = fetchFoodDepartment();
    _initializeFoodItems();
  }

  /// Initialize Smart Database Service with FTS5 fallback
  Future<void> _initializeSmartDatabase() async {
    try {
      await _smartDB.initialize();
      developer.log('Smart Database Service initialized successfully', name: 'RestaurantScreen');
    } catch (e) {
      developer.log('Error initializing Smart Database Service: $e', name: 'RestaurantScreen');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  /// Initialize offline data manager and smart preloading
  Future<void> _initializeOfflineData() async {
    try {
      await _offlineDataManager.initialize();
      await _preloadingCoordinator.initialize();
      await _connectionMonitor.initialize();
      
      final adminUid = await fetchAdminUid();
      if (adminUid.isNotEmpty && !adminUid.contains('Error') && !adminUid.contains('Offline')) {
        _preloadingCoordinator.setUserPreloadingStrategy(
          adminUid, 
          PreloadingStrategy(priority: PreloadingPriority.medium)
        );
        _preloadingCoordinator.triggerImmediatePreloading(adminUid);
      }
    } catch (e) {
      developer.log('Error initializing offline data: $e', name: 'RestaurantScreen');
    }
  }

  /// Initialize offline bill manager
  Future<void> _initializeOfflineBillManager() async {
    try {
      await _offlineBillManager.initialize();
      developer.log('Offline bill manager initialized successfully', name: 'RestaurantScreen');
    } catch (e) {
      developer.log('Error initializing offline bill manager: $e', name: 'RestaurantScreen');
    }
  }

  /// Setup search listener with debouncing
  void _setupSearchListener() {
    _searchController.addListener(() {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(_searchController.text);
      });
    });
  }

  /// Perform search
  void _performSearch(String query) {
    if (!mounted) return;
    
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
    
    if (_isSearching) {
      _performSmartSearch(_searchQuery);
    } else {
      setState(() {
        _filteredFoodItems = List.from(_allFoodItems);
      });
    }
  }

  /// Perform smart search using FTS5 or fallback
  Future<void> _performSmartSearch(String searchTerm) async {
    try {
      final String adminUid = await fetchAdminUid();
      
      final List<Map<String, dynamic>> searchResults = await _smartDB.searchFoodItems(
        adminUid,
        searchTerm,
        department: selectedDepartment.isNotEmpty ? selectedDepartment : null,
        limit: 50,
      );

      final List<Map<String, dynamic>> formattedResults = searchResults.map((item) {
        return {
          'id': item['id'] ?? item['name'],
          'name': item['name'] ?? 'N/A',
          'price': PriceUtils.safePriceToString(item['price']),
          'imagePath': item['image_path'] ?? item['imagePath'] ?? 'N/A',
          'foodCode': PriceUtils.safePriceToString(item['food_code'] ?? item['foodCode'], defaultValue: 'N/A'),
          'department': item['department'] ?? 'N/A',
          'stocks': PriceUtils.safePriceToString(item['stocks'], defaultValue: '0')
        };
      }).toList();

      setState(() {
        _filteredFoodItems = formattedResults;
      });

      developer.log('Smart search completed: "${searchTerm}" - ${formattedResults.length} results', name: 'RestaurantScreen');
    } catch (e) {
      developer.log('Smart search failed: $e', name: 'RestaurantScreen');
      setState(() {
        _filteredFoodItems = _allFoodItems.where((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final code = (item['foodCode'] ?? '').toString().toLowerCase();
          final department = (item['department'] ?? '').toString().toLowerCase();
          
          return name.contains(_searchQuery) || 
                 code.contains(_searchQuery) || 
                 department.contains(_searchQuery);
        }).toList();
      });
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
      developer.log('Error initializing food items: $e', name: 'RestaurantScreen');
    }
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
        developer.log('Network error fetching adminUid: ${e.message}', name: 'RestaurantScreen');
        try {
          final box = await Hive.openBox('userCache');
          final cachedAdminUid = box.get('adminUid_${widget.phoneNo}');
          if (cachedAdminUid != null) {
            developer.log('Using cached adminUid: $cachedAdminUid', name: 'RestaurantScreen');
            setState(() {
              this.adminUid = cachedAdminUid;
            });
            return cachedAdminUid;
          }
        } catch (cacheError) {
          developer.log('Error accessing cache: $cacheError', name: 'RestaurantScreen');
        }
        
        setState(() {
          this.adminUid = 'Offline - Admin UID unavailable';
        });
        return 'Offline - Admin UID unavailable';
      } else {
        developer.log('Error fetching adminUid: $e', name: 'RestaurantScreen');
        return 'Error fetching adminUid';
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchFoodDepartment() async {
    try {
      final String adminUid = await fetchAdminUid();
      final DatabaseService databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      final List<Map<String, dynamic>> allDepartments = await databaseService.getDepartments(adminUid);

      List<Map<String, dynamic>> departments = allDepartments
          .where((dept) => dept['status'] == 'Active')
          .map((dept) => {
                'id': dept['id'] ?? dept['name'],
                'name': dept['name'] ?? 'N/A',
                'imageUrl': dept['image_url'] ?? dept['imageUrl'] ?? 'N/A'
              })
          .toList();

      developer.log('Fetched departments: $departments', name: 'RestaurantScreen');

      return departments;
    } catch (e) {
      NetworkErrorHandler.logNetworkError(e, 'RestaurantScreen', 'fetchFoodDepartment');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFoodItems(String department) async {
    try {
      final String adminUid = await fetchAdminUid();
      final DatabaseService databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      final String targetDepartment = selectedDepartment.isEmpty ? 'Pizza' : selectedDepartment;
      final List<Map<String, dynamic>> allItems = await databaseService.getFoodItems(adminUid);

      List<Map<String, dynamic>> items = allItems
          .where((item) => item['department'] == targetDepartment)
          .map((item) => {
                'id': item['id'] ?? item['name'],
                'name': item['name'] ?? 'N/A',
                'price': PriceUtils.safePriceToString(item['price']),
                'imagePath': item['image_path'] ?? item['imagePath'] ?? 'N/A',
                'foodCode': PriceUtils.safePriceToString(item['food_code'] ?? item['foodCode'], defaultValue: 'N/A'),
                'department': item['department'] ?? 'N/A',
                'stocks': PriceUtils.safePriceToString(item['stocks'], defaultValue: '0')
              })
          .toList();

      setState(() {
        _allFoodItems = items;
        _filteredFoodItems = _isSearching ? _filteredFoodItems : List.from(items);
        isLoading = false;
      });

      developer.log('Fetched food items for $department: ${items.length} items', name: 'RestaurantScreen');

      return _isSearching ? _filteredFoodItems : items;
    } catch (e) {
      NetworkErrorHandler.logNetworkError(e, 'RestaurantScreen', 'fetchFoodItems');
      setState(() {
        isLoading = false;
      });
      return [];
    }
  }

  /// Build search capabilities info widget
  Widget _buildSearchCapabilitiesInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _smartDB.getSearchCapabilities(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final capabilities = snapshot.data!;
        final searchType = capabilities['searchType'] ?? 'Basic';
        final fts5Available = capabilities['fts5Available'] ?? false;
        
        if (fts5Available) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Using $searchType search (FTS5 not available)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build search bar for menu items
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search menu items, codes, or departments...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
        textInputAction: TextInputAction.search,
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
          actions: [
            const OfflineStatusIndicator(showWhenOnline: false),
            const SizedBox(width: 8),
            IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => UsersScreen()));
                },
                icon: const Icon(Icons.save))
          ],
          leading: IconButton(
            icon: isContainerVisible ? Icon(MdiIcons.fullscreen) : Icon(MdiIcons.fullscreenExit),
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
            style: TextStyle(color: Colors.black, fontFamily: 'tabfont', fontSize: 19),
          ),
        ),
        body: Column(
          children: [
            // Enhanced offline status banner with data availability info
            banner.OfflineStatusBanner(
              adminUid: adminUid,
              showDataStats: true,
            ),
            // Search capabilities info
            _buildSearchCapabilitiesInfo(),
            // Search bar for menu items
            _buildSearchBar(),
            Expanded(
              child: isLoading
                  ? ui_perf.SmoothTransition(
                      child: Container(
                        color: Colors.grey.withOpacity(0.1),
                        child: Row(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width * 0.21,
                              child: EnhancedLoadingStates.buildDepartmentSkeletonList(
                                itemCount: 6,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: EnhancedLoadingStates.buildFoodItemSkeletonGrid(
                                  context: context,
                                  itemCount: 6,
                                  crossAxisCount: isContainerVisible ? 2 : 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.withOpacity(0.1),
                      width: double.infinity,
                      height: double.infinity,
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isContainerVisible ? MediaQuery.of(context).size.width * 0.21 : 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: white,
                              ),
                              child: FutureBuilder<List<Map<String, dynamic>>>(
                                future: foodDepartmentsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Center(child: Text('Error: ${snapshot.error}'));
                                  } else {
                                    List<Map<String, dynamic>> departments = snapshot.data ?? [];
                                    return ListView.builder(
                                      itemCount: departments.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 7),
                                          child: GestureDetector(
                                            onTap: () async {
                                              setState(() {
                                                currentCategoryIndex = index;
                                                selectedDepartment = departments[index]['name'] ?? '';
                                              });

                                              if (adminUid.isNotEmpty && !adminUid.contains('Error') && !adminUid.contains('Offline')) {
                                                _preloadingCoordinator.trackUserInteraction(
                                                  adminUid, 
                                                  UserInteractionType.departmentAccess,
                                                  department: selectedDepartment
                                                );
                                              }

                                              foodItemsFuture = fetchFoodItems(selectedDepartment);
                                            },
                                            child: Column(
                                              children: [
                                                Stack(
                                                  children: [
                                                    AnimatedContainer(
                                                      duration: const Duration(milliseconds: 300),
                                                      margin: const EdgeInsets.all(5),
                                                      height: 60,
                                                      width: 60,
                                                      decoration: BoxDecoration(
                                                        color: currentCategoryIndex == index ? const Color.fromARGB(106, 133, 238, 187) : Colors.blueGrey.shade50,
                                                        borderRadius: BorderRadius.circular(30),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      bottom: 5,
                                                      left: 6,
                                                      right: 4,
                                                      child: AnimatedContainer(
                                                        height: currentCategoryIndex == index ? 65 : 55,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(55),
                                                        ),
                                                        duration: const Duration(milliseconds: 400),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(100),
                                                          child: CachedBlobImage(
                                                            imageUrl: departments[index]['imageUrl'],
                                                            tableName: 'departments',
                                                            recordId: departments[index]['id'] ?? departments[index]['name'] ?? 'unknown',
                                                            height: 40,
                                                            width: 30,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  departments[index]['name'] ?? 'N/A',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontFamily: 'fontmain',
                                                    fontWeight: currentCategoryIndex == index ? FontWeight.bold : FontWeight.w400,
                                                    color: currentCategoryIndex == index ? Colors.black : Colors.grey,
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
                          Expanded(
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: foodItemsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                } else if (snapshot.hasError) {
                                  return Center(child: Text('Error: ${snapshot.error}'));
                                } else {
                                  List<Map<String, dynamic>> foodItemsList = _isSearching ? _filteredFoodItems : (snapshot.data ?? []);
                                  
                                  if (foodItemsList.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No items found',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    );
                                  }

                                  return GridView.builder(
                                    controller: _gridViewController,
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isContainerVisible ? 2 : 3,
                                      childAspectRatio: 0.78,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: foodItemsList.length,
                                    itemBuilder: (context, index) {
                                      final item = foodItemsList[index];
                                      return GestureDetector(
                                        onTap: () async {
                                          audioPlayer.play(AssetSource('sounds/beep.mp3'));
                                          
                                          if (adminUid.isNotEmpty && !adminUid.contains('Error') && !adminUid.contains('Offline')) {
                                            final itemId = item['id'] ?? item['name'] ?? '';
                                            if (itemId.isNotEmpty) {
                                              _preloadingCoordinator.trackUserInteraction(
                                                adminUid, 
                                                UserInteractionType.itemAccess,
                                                department: selectedDepartment,
                                                itemId: itemId
                                              );
                                            }
                                          }
                                          
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
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                                                          fontSize: 13,
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (item['foodCode'] != null && item['foodCode'] != 'N/A')
                                                        Text(
                                                          'Code: ${item['foodCode']}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      const Spacer(),
                                                      Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(color: appbar1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              Icons.add_shopping_cart,
                                                              color: appbar1,
                                                              size: 14,
                                                            ),
                                                            Text(
                                                              " Add",
                                                              style: TextStyle(
                                                                fontFamily: 'tabfont',
                                                                color: appbar1,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 11,
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
                                  );
                                }
                              },
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
  }
}