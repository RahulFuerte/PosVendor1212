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
import 'package:pos/view/home/printer_connectionDialog.dart';
// import 'package:pos/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/menuItems.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/network_error_handler.dart';
import 'package:pos/view/tab_screen/view-model/backend/price_utils.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:provider/provider.dart';


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

  DateTime? currentBackPressTime;
  @override
  void initState() {
    super.initState();
    foodDepartmentsFuture = fetchFoodDepartment();
    // Initialize food items after departments are loaded
    _initializeFoodItems();
  }

  Future<void> _initializeFoodItems() async {
    try {
      // Wait for departments to load first
      List<Map<String, dynamic>> departments = await foodDepartmentsFuture;

      if (departments.isNotEmpty) {
        setState(() {
          // Set the first department as selected
          selectedDepartment = departments[0]['name'] ?? '';
          // Now fetch food items for the first department
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
        // Try to get cached adminUid from local storage if available
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

      // Get all departments using DatabaseService
      List<Map<String, dynamic>> allDepartments = await databaseService.getDepartments(adminUid);

      // Filter for active departments
      List<Map<String, dynamic>> departments = allDepartments
          .where((dept) => dept['status'] == 'Active')
          .map((dept) => {
                'id': dept['id'] ?? dept['name'], // Include ID for BLOB caching
                'name': dept['name'] ?? 'N/A',
                'imageUrl': dept['image_url'] ?? dept['imageUrl'] ?? 'N/A' // Support both formats
              })
          .toList();

      // Log for debugging
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

      // Get food items for specific department using DatabaseService
      List<Map<String, dynamic>> allItems = await databaseService.getFoodItems(adminUid, department: selectedDepartment.isEmpty ? 'Pizza' : selectedDepartment);

      List<Map<String, dynamic>> items = allItems
          .map((item) => {
                'id': item['id'] ?? item['name'], // Include ID for BLOB caching
                'name': item['name'] ?? 'N/A',
                'price': PriceUtils.safePriceToString(item['price']),
                'imagePath': item['image_path'] ?? item['imagePath'] ?? 'N/A', // Support both formats
                'foodCode': PriceUtils.safePriceToString(item['food_code'] ?? item['foodCode'], defaultValue: 'N/A'), // Ensure string type
                'department': item['department'] ?? 'N/A',
                'stocks': PriceUtils.safePriceToString(item['stocks'], defaultValue: '0') // Ensure string type
              })
          .toList();
      setState(() {
        isLoading = false;
      });
      // Log for debugging
      developer.log('Fetched food items for $department: $items', name: 'RestaurantScreen');

      return items;
    } catch (e) {
      NetworkErrorHandler.logNetworkError(e, 'RestaurantScreen', 'fetchFoodItems');
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
        child: Image.network(
          urlImage,
          fit: BoxFit.cover,
        ),
      );
  final ScrollController _gridViewController = ScrollController();

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
          return false; // Don't exit the app yet
        }
        return true; // Allow the app to exit
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
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
          // elevation: 1,
          backgroundColor: Colors.white,
          title: const Text(
            'Restaurants',
            style: TextStyle(color: Colors.black, fontFamily: 'tabfont', fontSize: 19),
          ),
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                color: appbar1,
              ))
            : Container(
                color: Colors.grey.withOpacity(0.1),
                width: double.infinity,
                height: double.infinity,
                //margin: const EdgeInsets.all(5),
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
                                      onTap: () {
                                        setState(() {
                                          currentCategoryIndex = index;
                                          selectedDepartment = departments[index]['name'] ?? '';
                                          departments[index]['imageUrl'] ?? '';
                                          // _listScrollController.jumpTo(
                                          //   _listScrollController
                                          //       .position.maxScrollExtent,
                                          // );
                                        });

                                        foodItemsFuture = fetchFoodItems(selectedDepartment);
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
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
                                                      // curve: Curves.easeInCubic,
                                                      height: currentCategoryIndex == index ? 65 : 55,
                                                      // width:
                                                      //     currentCategoryIndex ==
                                                      //             index
                                                      //         ? 77
                                                      //         : 50,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(55),
                                                      ),
                                                      duration: const Duration(milliseconds: 400),
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            currentCategoryIndex = index;
                                                            selectedDepartment = departments[index]['name'] ?? '';
                                                            departments[index]['imageUrl'] ?? '';
                                                          });
                                                          foodItemsFuture = fetchFoodItems(selectedDepartment);
                                                        },
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
                                          Container(
                                            height: 100,
                                            width: 5,
                                            decoration: BoxDecoration(
                                                color: currentCategoryIndex == index ? appbar1 : Colors.white,
                                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(21), bottomLeft: Radius.circular(21))),
                                          )
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

                    /// MAIN BODY
                    Expanded(
                      child: Column(
                        children: [
                          printprovider.posts.isNotEmpty ? billCountContainer() : SizedBox(),
                          Expanded(
                            child: Container(
                              child: FutureBuilder(
                                future: foodItemsFuture,
                                builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: primaryColor,
                                      ),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Center(
                                      child: Text('Error: ${snapshot.error}'),
                                    );
                                  } else {
                                    List<Map<String, dynamic>> foodItemsList = snapshot.data ?? [];

                                    return GridView.builder(
                                      controller: _gridViewController,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isContainerVisible ? 2 : 3,
                                        childAspectRatio: 0.78, // Slightly taller to prevent overflow
                                      ),
                                      itemCount: foodItemsList.length,
                                      itemBuilder: (context, index) {
                                        final item = foodItemsList[index];
                                        return GestureDetector(
                                          onTap: () {
                                            audioPlayer.play(AssetSource('sounds/beep.mp3'));
                                            setState(() {
                                              isTapped = true;
                                              selectedItemName = item['name'] ?? '';
                                              selectedItemPrice = PriceUtils.safeParseInt(item['price']);

                                              // Check if the item is already in the list
                                              int existingIndex = selectedItemsDetails.indexWhere(
                                                (element) => element['name'] == selectedItemName && element['price'] == selectedItemPrice,
                                              );

                                              if (existingIndex != -1) {
                                                // If the item already exists, increase its quantity by 1
                                                selectedItemsDetails[existingIndex]['quantity'] += 1;
                                              } else {
                                                // If the item is not in the list, add it with quantity 1
                                                selectedItemsDetails.add({
                                                  'name': selectedItemName,
                                                  'price': selectedItemPrice,
                                                  'quantity': 1,
                                                  // Add totalPrice field here
                                                });
                                              }

                                              subtotal += selectedItemPrice;

                                              printprovider.additem(selectedItemsDetails, subtotal);

                                              setState(() {
                                                _listScrollController.jumpTo(
                                                  _listScrollController.position.maxScrollExtent,
                                                );
                                              });
                                            });
                                          },
                                          child: MenuItem(
                                            context: context,
                                            imagePath: item['imagePath'] ?? '',
                                            text: item['name'] ?? '',
                                            code: PriceUtils.safePriceToString(item['foodCode'], defaultValue: 'N/A'),
                                            price: PriceUtils.safePriceToString(item['price']),
                                            stocks: PriceUtils.safePriceToString(item['stocks'], defaultValue: '0'),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          // printprovider.posts.isNotEmpty ? billCountContainer() : const SizedBox(),
                        ],
                      ),
                    ),
                  ],
                ),
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
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                    const Text(
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
              itemCount: selectedItemsDetails.length,
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
                          size: 24,
                        ),
                        onPressed: () async {
                          await _showSaveBottomSheet();
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
                                // Fetch shop data with network error handling
                                final doc = await NetworkErrorHandler.executeWithNetworkHandling<DocumentSnapshot<Map<String, dynamic>>>(
                                  operation: () => FirebaseFirestore.instance.collection('AllAdmins').doc(adminUid).collection('customer').doc(widget.phoneNo).get(),
                                  context: context,
                                  operationName: 'fetchShopData',
                                  component: 'RestaurantScreen',
                                  showUserMessage: false,
                                ) ?? await FirebaseFirestore.instance.collection('AllAdmins').doc(adminUid).collection('customer').doc(widget.phoneNo).get();

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

  Future<void> _showSaveBottomSheet() async {
    // Get the provider BEFORE showing the bottom sheet
    final printprovider = Provider.of<PrintProvider>(
      context,
      listen: false, // Important: use listen: false
    );

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
                      printprovider.clearCart(); // Now this will work
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
      'userName': userNameController.text,
      'details': selectedItemsDetails,
      'totalAmount': subtotal,
    };

    // Save data to Hive
    final box = await Hive.openBox('userBox');
    box.add(userMap);
    userNameController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UsersScreen(),
      ),
    );
  }

// List<Map<String, dynamic>> _encodeDetails(List<Map<String, dynamic>> details) {
//   return details.map((item) {
//     return {
//       'name': item['name'],
//       'price': item['price'],
//       'quantity': item['quantity'],
//     };
//   }).toList();
// }
}
