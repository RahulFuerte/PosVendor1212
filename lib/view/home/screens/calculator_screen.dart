// Dart imports:
import 'dart:developer' as developer;
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/print_provider.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import '../widgets/bill_cart_widget.dart';
import '../widgets/show_save_order_bottom_sheet.dart';

class PLUCalculatorScreen extends StatefulWidget {
  final String phoneNumber;

  const PLUCalculatorScreen({super.key, required this.phoneNumber});
  @override
  // ignore: library_private_types_in_public_api
  _PLUPageState createState() => _PLUPageState();
}

class _PLUPageState extends State<PLUCalculatorScreen> {
  TextEditingController userNameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();

  AudioPlayer audioPlayer = AudioPlayer();
  bool isTapped = false;
  String adminUid = '';
  String previousItemName = '';
  int previousItemPrice = 0;

  List<Map<String, dynamic>> cartItems = [];
  final TextEditingController _textEditingController = TextEditingController();
  bool isInputNotEmpty = false;
  DateTime? currentBackPressTime;
  late Future<List<Map<String, dynamic>>> foodItemsFuture;

  @override
  void initState() {
    super.initState();
    foodItemsFuture = fetchFoodItems();
    _textEditingController.addListener(() {
      setState(() {
        isInputNotEmpty = _textEditingController.text.isNotEmpty;
      });
    });

    // Sync with provider on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final printprovider = Provider.of<PrintProvider>(context, listen: false);
      if (printprovider.posts.isNotEmpty) {
        cartItems = List<Map<String, dynamic>>.from(printprovider.posts);
        totalSum = printprovider.total;
      }
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
        _textEditingController.text = _textEditingController.text
            .substring(0, _textEditingController.text.length - 1);
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

  Future<String> fetchAdminUid() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('AllCustomer')
          .doc(widget.phoneNumber)
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
            'phoneNumber': widget.phoneNumber,
            'name': data?['name'],
            'email': data?['email'],
            'customerCode': data?['customerCode'],
            'createdAt': data?['createdAt'],
          });
        } catch (cacheError) {
          developer.log('Error caching adminUid in SQLite: $cacheError',
              name: 'CalculatorScreen');
        }

        setState(() {
          adminUid = fetchedAdminUid;
        });
        return fetchedAdminUid;
      }

      // If Firebase returned null, try SQLite cache
      return await _getCachedAdminUid();
    } catch (e) {
      developer.log('Error fetching adminUid: $e', name: 'CalculatorScreen');
      // Fall back to cached adminUid from SQLite when offline
      return await _getCachedAdminUid();
    }
  }

  /// Get cached adminUid from SQLite for offline use
  Future<String> _getCachedAdminUid() async {
    try {
      final sqliteHelper = SQLiteHelper();
      final cachedAdminUid = await sqliteHelper.getAdminUid(widget.phoneNumber);

      if (cachedAdminUid != null && cachedAdminUid.isNotEmpty) {
        developer.log('Using cached adminUid from SQLite: $cachedAdminUid',
            name: 'CalculatorScreen');
        setState(() {
          adminUid = cachedAdminUid;
        });
        return cachedAdminUid;
      }

      // Last resort: use phoneNumber as adminUid
      developer.log('No cached adminUid found, using phoneNumber as fallback',
          name: 'CalculatorScreen');
      setState(() {
        adminUid = widget.phoneNumber;
      });
      return widget.phoneNumber;
    } catch (e) {
      developer.log('Error getting cached adminUid from SQLite: $e',
          name: 'CalculatorScreen');
      setState(() {
        adminUid = widget.phoneNumber;
      });
      return widget.phoneNumber;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFoodItems() async {
    try {
      final String adminUid = await fetchAdminUid();
      final DatabaseService databaseService =
          Provider.of<DatabaseService>(context, listen: false);

      // Get all food items using DatabaseService
      List<Map<String, dynamic>> allItems =
          await databaseService.getFoodItems(adminUid);

      List<Map<String, dynamic>> items = allItems
          .map((item) => {
                'name': PriceUtils.safeStringConversion(item['name']),
                'price': PriceUtils.safeStringConversion(item['price']),
                'foodCode': PriceUtils.safeStringConversion(item['food_code'] ??
                    item['foodCode']) // Support both formats
              })
          .toList();

      developer.log('Fetched food items of cs: $items',
          name: 'CalculatorScreen');

      return items;
    } catch (e) {
      developer.log('Error fetching food items: $e', name: 'CalculatorScreen');
      return [];
    }
  }

  void checkFoodItem(String foodCode) async {
    developer.log('cs foodcode: $foodCode', name: 'CalculatorScreen');
    try {
      List<Map<String, dynamic>> foodItems = await foodItemsFuture;

      for (var item in foodItems) {
        if (item['foodCode'] == foodCode) {
          // Use safe price conversion
          int parsedPrice = PriceUtils.safePriceConversion(item['price']);
          String itemName = PriceUtils.safeStringConversion(item['name']);

          if (parsedPrice > 0 && itemName.isNotEmpty) {
            setState(() {
              isTapped = true;
              previousItemName = itemName;
              previousItemPrice = parsedPrice;
            });
            addToCart(previousItemName, previousItemPrice);
            _textEditingController.clear(); // Clear input after adding
            return;
          } else {
            developer.log(
                'Invalid item data: name=$itemName, price=${item['price']}',
                name: 'CalculatorScreen');
            Fluttertoast.showToast(
              msg: "Invalid item data for code: $foodCode",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
            return;
          }
        }
      }

      developer.log('Food Item not found for code: $foodCode',
          name: 'CalculatorScreen');
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

  @override
  Widget build(BuildContext context) {
    final printprovider = Provider.of<PrintProvider>(context, listen: true);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
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
        } else {
          // Exit the app
          exit(0); // Exit the app
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 1,
          title: const Text(
            'Enter Food code',
            style: TextStyle(
                color: Colors.black, fontFamily: 'tabfont', fontSize: 19),
          ),
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.09,
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 28,
                          fontFamily: "tabfont",
                          color: primaryColor,
                        ),
                        readOnly: true,
                        controller: _textEditingController,
                        cursorColor: primaryColor,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black38),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: primaryColor),
                          ),
                          focusColor: primaryColor,
                          hoverColor: primaryColor,
                          suffixIcon: isInputNotEmpty
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.backspace_outlined,
                                        color: primaryColor,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        if (_textEditingController
                                            .text.isNotEmpty) {
                                          _textEditingController.text =
                                              _textEditingController.text
                                                  .substring(
                                                      0,
                                                      _textEditingController
                                                              .text.length -
                                                          1);
                                        }
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  ],
                ),
                GridView.count(
                  childAspectRatio: 1.5,
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var buttonValue in [
                      '1',
                      '2',
                      '3',
                      '4',
                      '5',
                      '6',
                      '7',
                      '8',
                      '9',
                      'C',
                      '0',
                      'PLU',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 5, right: 5, top: 4, bottom: 4),
                        child: ElevatedButton(
                          onPressed: () {
                            audioPlayer.play(AssetSource('sounds/beep.mp3'));
                            onKeyPressed(buttonValue);
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: primaryColor,
                            elevation: 5,
                            backgroundColor: buttonValue == 'PLU'
                                ? primaryColor
                                : Colors.white,
                            shadowColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            buttonValue,
                            style: TextStyle(
                              fontFamily: "tabfont",
                              color:
                                  buttonValue == 'PLU' ? Colors.white : appbar1,
                              fontSize: 25,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Use Flexible to allow the cart container to take available space
                if (printprovider.posts.isNotEmpty)
                  Flexible(
                    fit: FlexFit.tight,
                    child: BillCart(
                      adminUid: adminUid,
                      phoneNo: widget.phoneNumber,
                      onCartCleared: () {
                        setState(() {
                          cartItems.clear();
                          totalSum = 0.0;
                        });
                      },
                      onCartUpdated: (List<Map<String, dynamic>> updatedItems,
                          double updatedTotal) {
                        setState(() {
                          cartItems = updatedItems;
                          totalSum = updatedTotal;
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
                          onSave: () {
                            _saveDataAndNavigate();
                            printprovider.clearCart();
                            userNameController.clear();
                            mobileController.clear();
                          },
                        );
                      },
                    ),
                  ),
                // const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
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
  //                 child: const Text('Submit'),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  void _saveDataAndNavigate() async {
    final printprovider = Provider.of<PrintProvider>(context, listen: false);
    final userMap = {
      'phoneNumber': mobileController.text,
      'userName': userNameController.text,
      'details': _encodeDetails(cartItems),
      'totalAmount': printprovider.total,
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

  List<Map<String, dynamic>> _encodeDetails(
      List<Map<String, dynamic>> details) {
    return details.map((item) {
      return {
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'],
      };
    }).toList();
  }
}
