import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:pos/view/home/usersDataScreen.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/receipt_preview.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/price_utils.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:provider/provider.dart';

import '../tab_screen/view-model/widgets/show_save_order_bottom_sheet.dart';

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

  Future<String> fetchAdminUid() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('AllCustomer')
          .doc(widget.phoneNumber)
          .get();

      final String? adminUid = snapshot.data()?['adminUid'];

      setState(() {
        this.adminUid = adminUid ?? 'Admin UID not found';
      });

      return adminUid ?? 'Admin UID not found';
    } catch (e) {
      developer.log('Error fetching adminUid: $e', name: 'CalculatorScreen');
      return 'Error fetching adminUid';
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
          elevation: 1,
          title: const Text(
            'Bill generator',
            style: TextStyle(
                color: Colors.black, fontFamily: 'tabfont', fontSize: 19),
          ),
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Enter Food Code:',
                  style: TextStyle(
                      fontSize: 18, fontFamily: "tabfont", letterSpacing: 2),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Row(
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
                              borderSide:
                                  const BorderSide(color: Colors.black38),
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
                ),
                const SizedBox(height: 16),
                GridView.count(
                  childAspectRatio: 1.3,
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
                const SizedBox(height: 16),
                // Use Flexible to allow the cart container to take available space
                if (printprovider.posts.isNotEmpty)
                  Flexible(
                    fit: FlexFit.tight,
                    child: billCountContainer(),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget billCountContainer() {
    final printprovider = Provider.of<PrintProvider>(context, listen: false);

    return Container(
      // height: 50,
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
                    '${printprovider.posts.length} Items',
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
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.50,
                minHeight: 200,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                itemCount: printprovider.posts.length,
                itemBuilder: (context, index) {
                  final item = printprovider.posts[index];
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
                          height: 50,
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
                                item['name'],
                                style: const TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${item['price']} × ${item['quantity']}',
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
                                    // Find the item in cartItems
                                    int cartIndex = cartItems.indexWhere(
                                        (cartItem) =>
                                            cartItem['name'] == item['name']);

                                    if (cartIndex != -1) {
                                      if (item['quantity'] > 1) {
                                        // Decrease quantity
                                        cartItems[cartIndex]['quantity']--;
                                        totalSum -=
                                            cartItems[cartIndex]['price'];
                                      } else {
                                        // Remove item when quantity is 1
                                        totalSum -= cartItems[cartIndex]
                                                ['price'] *
                                            cartItems[cartIndex]['quantity'];
                                        cartItems.removeAt(cartIndex);
                                      }
                                      printprovider.additem(
                                          cartItems, totalSum);
                                    }
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  "${item['quantity']}",
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
                                    // Find the item in cartItems
                                    int cartIndex = cartItems.indexWhere(
                                        (cartItem) =>
                                            cartItem['name'] == item['name']);
                                    if (cartIndex != -1) {
                                      cartItems[cartIndex]['quantity']++;
                                      totalSum += cartItems[cartIndex]['price'];
                                      printprovider.additem(
                                          cartItems, totalSum);
                                    }
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
                              // Find the item in cartItems by name
                              int cartIndex = cartItems.indexWhere((cartItem) =>
                                  cartItem['name'] == item['name']);

                              if (cartIndex != -1) {
                                // Subtract the total price of this item from totalSum
                                totalSum -= cartItems[cartIndex]['price'] *
                                    cartItems[cartIndex]['quantity'];

                                // Remove the item from cartItems
                                cartItems.removeAt(cartIndex);

                                // Update the provider
                                printprovider.additem(cartItems, totalSum);
                              }
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
                      "₹${printprovider.total}",
                      style: const TextStyle(
                        fontSize: 18,
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
                          Icons.receipt_long_outlined,
                          color: appbar1,
                          size: 24,
                        ),
                        onPressed: () async {
                          if (cartItems.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No items in cart'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          // Fetch shop data
                          final doc = await FirebaseFirestore.instance
                              .collection('AllAdmins')
                              .doc(adminUid)
                              .collection('customer')
                              .doc(widget.phoneNumber)
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

                          // Navigate to preview screen
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReceiptPreviewScreen(
                                adminUid: adminUid,
                                shopName: shopName,
                                contact: contact,
                                address: address,
                                phoneNo: widget.phoneNumber,
                              ),
                            ),
                          );

                          // If cart was updated in preview, refresh
                          if (result != null) {
                            setState(() {
                              cartItems = result['items'];
                              totalSum = result['subtotal'];
                              final printprovider = Provider.of<PrintProvider>(
                                  context,
                                  listen: false);
                              printprovider.additem(cartItems, totalSum);
                            });
                          }
                        },
                      ),
                    ),
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
                          size: 24,
                        ),
                        onPressed: () async {
                          await _showSaveBottomSheet();
                          // SaveOrderBottomSheet(formKey: _formKey, nameController: userNameController,mobileController: mobileController,onSave: () => ,);
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
                              color: printProvider.isConnected
                                  ? Colors.green
                                  : Colors.white,
                              size: 24,
                            ),
                            onPressed: () async {
                              if (!printProvider.isConnected ||
                                  printProvider.selectedPrinter == null) {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const PrinterConnectionDialog(),
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Please connect a printer first'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              if (cartItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No items to print'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              try {
                                final doc = await FirebaseFirestore.instance
                                    .collection('AllAdmins')
                                    .doc(adminUid)
                                    .collection('customer')
                                    .doc(widget.phoneNumber)
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

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }

                                await DirectPrintHelper.printReceipt(
                                  adminUid: widget.phoneNumber,
                                  context: context,
                                  printer: printProvider.selectedPrinter!,
                                  paperSize: printProvider.selectedPaperSize,
                                  items: cartItems,
                                  total: printprovider.total,
                                  shopName: shopName,
                                  contact: contact,
                                  address: address,
                                );

                                // Clear the cart after successful printing
                                setState(() {
                                  cartItems.clear();
                                  totalSum = 0.0;
                                });
                                printprovider.clearCart();
                              } catch (e) {
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // TextEditingController userNameController = TextEditingController();
  Future<void> _showSaveBottomSheet() async {
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
    final printprovider = Provider.of<PrintProvider>(context, listen: false);
    final userMap = {
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
