// Dart imports:
import 'dart:developer' as developer;

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bill_cart_widget.dart';
import '../widgets/show_save_order_bottom_sheet.dart';

class PLUCalculatorScreen extends StatefulWidget {
  const PLUCalculatorScreen({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _PLUPageState createState() => _PLUPageState();
}

class _PLUPageState extends State<PLUCalculatorScreen> {
  TextEditingController userNameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();

  AudioPlayer audioPlayer = AudioPlayer();

  String phoneNumber = '';
  String adminUid = '';
  bool isTapped = false;
  String previousItemName = '';
  int previousItemPrice = 0;

  final TextEditingController _textEditingController = TextEditingController();
  bool isInputNotEmpty = false;
  DateTime? currentBackPressTime;

  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> allFoodItems = [];
  List<Map<String, dynamic>> filteredFoodItems = [];

  late Future<List<Map<String, dynamic>>> foodItemsFuture;

  bool isSearching = false;
  String search1 = '';

  TextEditingController restaurantSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    foodItemsFuture = fetchFoodItems().then((items) {
      if (mounted) {
        setState(() {
          allFoodItems = items;
          filteredFoodItems = items;
        });
      }
      return items;
    });
    _loadSessionData();

    _textEditingController.addListener(() {
      if (mounted) {
        setState(() {
          isInputNotEmpty = _textEditingController.text.isNotEmpty;
        });
      }
    });

    // Pre-open Hive box to avoid repeated file system hits
    Hive.openBox('userBox');

    // Sync with provider on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final printprovider = Provider.of<PrintProvider>(context, listen: false);
      if (printprovider.posts.isNotEmpty) {
        setState(() {
          cartItems = List<Map<String, dynamic>>.from(printprovider.posts);
          totalSum = printprovider.total;
        });
      }
    });
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNumber = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    userNameController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  double totalSum = 0.0;
  int currentItemQuantity = 0;

  void addToCart(String itemName, int itemPrice) {
    final printprovider = Provider.of<PrintProvider>(context, listen: false);

    // First, sync cartItems with printprovider.posts to ensure consistency
    if (cartItems.isEmpty && printprovider.posts.isNotEmpty) {
      cartItems = List<Map<String, dynamic>>.from(printprovider.posts);
      // Recalculate totalSum from existing items
      totalSum = 0.0;
      for (var item in cartItems) {
        totalSum += (item['price'] * item['quantity']).toDouble();
      }
    }

    // Check if the item already exists in the cart
    bool itemFound = false;
    for (var cartItem in cartItems) {
      if (cartItem['name'] == itemName) {
        setState(() {
          cartItem['quantity'] = (cartItem['quantity'] ?? 1) + 1;
          totalSum = totalSum + itemPrice;
          currentItemQuantity = cartItem['quantity'];
          printprovider.additem(cartItems, totalSum);
        });
        itemFound = true;
        break; // Exit loop once item is found and updated
      }
    }

    // If the item is not in the cart, add it with quantity 1
    if (!itemFound) {
      setState(() {
        cartItems.add({
          'name': itemName,
          'price': itemPrice,
          'quantity': 1,
        });

        totalSum += itemPrice.toDouble();
        currentItemQuantity = 1;
        printprovider.additem(cartItems, totalSum);
      });
    }
  }

  void onKeyPressed(String value) {
    if (value == 'C') {
      // Clear the text field
      _textEditingController.text = '';
    } else if (value == '⌫') {
      // Backspace - remove last character
      if (_textEditingController.text.isNotEmpty) {
        _textEditingController.text = _textEditingController.text.substring(0, _textEditingController.text.length - 1);
      }
    } else if (value == 'PLU') {
      String enteredCode = _textEditingController.text;
      if (enteredCode.isNotEmpty) {
        checkFoodItem(enteredCode);
      } else {
        Fluttertoast.showToast(
          msg: "No item exists with the given code",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: primaryColor,
          textColor: Colors.white,
        );
      }
    } else {
      _textEditingController.text += value;
    }
  }

  Future<void> showSaveOrderBottomSheet({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController mobileController,
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
          gstController: nameController,
          addressController: mobileController,
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

  Future<String> fetchAdminUid() async {
    try {
      // Check connection status first
      final sqliteHelper = SQLiteHelper();
      // Try SQLite cache first for adminUid
      final cachedUid = await sqliteHelper.getAdminUid(phoneNumber);
      if (cachedUid != null && cachedUid.isNotEmpty) {
        setState(() {
          adminUid = cachedUid;
        });
        return cachedUid;
      }
      // Fallback to phoneNumber as adminUid
      setState(() {
        adminUid = phoneNumber;
      });
      return phoneNumber;
    } catch (e) {
      return await _getCachedAdminUid();
    }
  }

  /// Get cached adminUid from SQLite for offline use
  Future<String> _getCachedAdminUid() async {
    try {
      final sqliteHelper = SQLiteHelper();
      final cachedAdminUid = await sqliteHelper.getAdminUid(phoneNumber);

      if (cachedAdminUid != null && cachedAdminUid.isNotEmpty) {
        developer.log('Using cached adminUid from SQLite: $cachedAdminUid', name: 'CalculatorScreen');
        setState(() {
          adminUid = cachedAdminUid;
        });
        return cachedAdminUid;
      }

      // Last resort: use phoneNumber as adminUid
      developer.log('No cached adminUid found, using phoneNumber as fallback', name: 'CalculatorScreen');
      setState(() {
        adminUid = phoneNumber;
      });
      return phoneNumber;
    } catch (e) {
      developer.log('Error getting cached adminUid from SQLite: $e', name: 'CalculatorScreen');
      setState(() {
        adminUid = phoneNumber;
      });
      return phoneNumber;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFoodItems() async {
    try {
      final products = await ProductService().getProducts();

      List<Map<String, dynamic>> items = products
          .map((item) => {
                'name': PriceUtils.safeStringConversion(item.name),
                'price': PriceUtils.safeStringConversion(item.price),
                'foodCode': PriceUtils.safeStringConversion(item.foodCode)
              })
          .toList();

      return items;
    } catch (e) {
      return [];
    }
  }

  void checkFoodItem(String foodCode) async {
    developer.log('cs foodcode: $foodCode', name: 'CalculatorScreen');
    try {
      // First, try direct fetch from service using the new foodCode parameter
      final products = await ProductService().getProducts(foodCode: foodCode);

      if (products.isNotEmpty) {
        final product = products.first;
        final int parsedPrice = product.price.round();
        final String itemName = product.name;

        if (parsedPrice > 0 && itemName.isNotEmpty) {
          setState(() {
            isTapped = true;
            previousItemName = itemName;
            previousItemPrice = parsedPrice;
          });
          addToCart(previousItemName, previousItemPrice);
          _textEditingController.clear();
          return;
        }
      }

      // Fallback: Check local cached data (useful for offline mode or demo data)
      final foodItems = await foodItemsFuture;
      final localMatch = foodItems.firstWhere(
        (item) => item['foodCode'] == foodCode,
        orElse: () => {},
      );

      if (localMatch.isNotEmpty) {
        final int parsedPrice = PriceUtils.safePriceConversion(localMatch['price']);
        final String itemName = PriceUtils.safeStringConversion(localMatch['name']);

        if (parsedPrice > 0 && itemName.isNotEmpty) {
          setState(() {
            isTapped = true;
            previousItemName = itemName;
            previousItemPrice = parsedPrice;
          });
          addToCart(previousItemName, previousItemPrice);
          _textEditingController.clear();
          return;
        }
      }

      developer.log('Food Item not found for code: $foodCode', name: 'CalculatorScreen');
      Fluttertoast.showToast(
        msg: "No item exists with code: $foodCode",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: primaryColor,
        textColor: Colors.white,
      );
    } catch (e) {
      developer.log('Error fetching food items: $e', name: 'CalculatorScreen');
      Fluttertoast.showToast(
        msg: "Error loading items. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void filterItems(String query) {
    if (query.isEmpty) {
      filteredFoodItems = allFoodItems;
    } else {
      filteredFoodItems = allFoodItems.where((item) {
        return item['name'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final printprovider = Provider.of<PrintProvider>(context, listen: true);

    return PopScope(
        // canPop: false,
        // onPopInvoked: (bool didPop) async {
        //   DateTime now = DateTime.now();
        //   if (currentBackPressTime == null ||
        //       now.difference(currentBackPressTime!) >
        //           const Duration(seconds: 2)) {
        //     currentBackPressTime = now;
        //     Fluttertoast.showToast(
        //       msg: "Press back again to exit",
        //       toastLength: Toast.LENGTH_SHORT,
        //       gravity: ToastGravity.BOTTOM,
        //       timeInSecForIosWeb: 2,
        //       backgroundColor: Colors.grey,
        //       textColor: Colors.white,
        //       fontSize: 16.0,
        //     );
        //   } else {
        //     // Exit the app
        //     exit(0); // Exit the app
        //   }
        // },
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              actions: [
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
              title: isSearching
                  ? Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: restaurantSearch,
                        autofocus: true,
                        onChanged: filterItems,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                            hintText: "Search Item Name",
                            prefixIcon: Icon(Icons.search, size: 18),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.all(15)),
                      ),
                    )
                  : const Row(
                      children: [
                        MyText(
                          text: 'Enter Food Code',
                          color: Colors.black,
                          fontSize: 20,
                        ),
                      ],
                    ),
            ),
            body: Column(
              children: [
                /// ================= SEARCH / KEYPAD AREA =================
                Expanded(
                  child: isSearching
                      ? ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: filteredFoodItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = filteredFoodItems[i];
                            return ListTile(
                              title: MyText(
                                text: item['name'],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              subtitle: MyText(text: PriceUtils.formatPrice(item['price'])),
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                                onPressed: () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.pop(context);
                                  } else {
                                    // If we can't pop, we are likely the root of a tab navigator.
                                    // We don't want to pop and leave a blank screen.
                                    developer.log("Calculator is at root, ignoring pop", name: "CalculatorScreen");
                                  }
                                },
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: primaryColor,
                                  size: 30,
                                ),
                                onPressed: () {
                                  addToCart(
                                    item['name'],
                                    PriceUtils.safePriceConversion(item['price']),
                                  );
                                },
                              ),
                            );
                          },
                        )
                      : Column(
                          children: [
                            /// ================= FOOD CODE DISPLAY =================
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: SizedBox(
                                height: 65,
                                width: MediaQuery.of(context).size.width * 0.9,
                                child: TextField(
                                  controller: _textEditingController,
                                  readOnly: true,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: primaryColor,
                                  ),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    suffixIcon: isInputNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.backspace_outlined,
                                              color: primaryColor,
                                            ),
                                            onPressed: () {
                                              _textEditingController.text = _textEditingController.text
                                                  .substring(0, _textEditingController.text.length - 1);
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),

                            /// ================= KEYPAD =================
                            Expanded(
                              child: FutureBuilder<List<Map<String, dynamic>>>(
                                future: foodItemsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting && allFoodItems.isEmpty) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  return GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 1.6,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: 12,
                                    itemBuilder: (_, index) {
                                      final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', 'PLU'];
                                      final key = keys[index];

                                      return ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            await audioPlayer.play(AssetSource('sounds/beep.mp3'));
                                          } catch (e) {
                                            developer.log("Audio play failed: $e");
                                          }
                                          onKeyPressed(key);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: key == 'PLU' ? primaryColor : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 4,
                                        ),
                                        child: MyText(
                                          text: key,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          color: key == 'PLU' ? Colors.white : appbar1,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            if (printprovider.posts.isNotEmpty)
                              BillCart(
                                onCartCleared: () {
                                  setState(() {
                                    cartItems.clear();
                                    totalSum = 0.0;
                                  });
                                },
                                onCartUpdated: (List<Map<String, dynamic>> items, double total) {
                                  setState(() {
                                    cartItems = items;
                                    totalSum = total;
                                  });
                                },
                                orderBottomSheet: () {
                                  showSaveOrderBottomSheet(
                                    context: context,
                                    formKey: _formKey,
                                    nameController: userNameController,
                                    mobileController: mobileController,
                                    itemCount: cartItems.length,
                                    totalAmount: totalSum,
                                    primaryColor: primaryColor,
                                    onSave: (customerId) {
                                      _saveDataAndNavigate(customerId);
                                      printprovider.clearCart();
                                      userNameController.clear();
                                      mobileController.clear();
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                ),

                /// ================= CART AREA =================
              ],
            )));
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // TextEditingController userNameController = TextEditingController();
  // Future<void> _showSaveBottomSheet() async {
  //   return showModalBottomSheet(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return Container(
  //         padding: const EdgeInsets.all(16),
  //         child: Form(
  //           key: _formKey,
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextFormField(
  //                 controller: userNameController,
  //                 decoration: const InputDecoration(labelText: 'User Name'),
  //                 validator: (value) {
  //                   if (value!.isEmpty) {
  //                     return 'Please enter a user name';
  //                   }
  //                   return null;
  //                 },
  //               ),
  //               const SizedBox(height: 16),
  //               ElevatedButton(
  //                 onPressed: () {
  //                   if (_formKey.currentState!.validate()) {
  //                     _saveDataAndNavigate();
  //                     userNameController.clear();
  //                   }
  //                 },
  //                 child: const MyText(text: 'Submit'),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  void _saveDataAndNavigate(String? customerId) async {
    final printprovider = Provider.of<PrintProvider>(context, listen: false);
    final userMap = {
      'phoneNumber': mobileController.text,
      'userName': userNameController.text,
      'details': _encodeDetails(cartItems),
      'totalAmount': printprovider.total,
      'customerId': customerId,
    };

    // Save data to Hive
    final box = await Hive.openBox('userBox');
    box.add(userMap);
    userNameController.clear();

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
}
