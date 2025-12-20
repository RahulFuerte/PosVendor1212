// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:image/image.dart' as img;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
// import 'package:intl/intl.dart';
// import 'package:pos/view/home/print_provider.dart';
// import 'package:provider/provider.dart';

// class Printer extends StatefulWidget {
//   final String adminUid;
//   final String userId;
//   List<Map<String, dynamic>> selectedItemsDetails = [];
//   double total = 0;
//   Printer({
//     Key? key,
//     required this.selectedItemsDetails,
//     required this.total,
//     required this.adminUid,
//     required this.userId,
//   }) : super(key: key);

//   @override
//   State<Printer> createState() => _PrinterState();
// }

// class _PrinterState extends State<Printer> {
//   // Printer Type [bluetooth, usb, network]
//   var defaultPrinterType = PrinterType.bluetooth;
//   var _isBle = false;
//   var _reconnect = false;
//   var _isConnected = false;
//   var printerManager = PrinterManager.instance;
//   var devices = <BluetoothPrinter>[];
//   StreamSubscription<PrinterDevice>? _subscription;
//   StreamSubscription<BTStatus>? _subscriptionBtStatus;
//   StreamSubscription<USBStatus>? _subscriptionUsbStatus;
//   BTStatus _currentStatus = BTStatus.none;
//   USBStatus _currentUsbStatus = USBStatus.none;
//   List<int>? pendingTask;
//   String _ipAddress = '';
//   String _port = '9100';
//   final _ipController = TextEditingController();
//   final _portController = TextEditingController();
//   BluetoothPrinter? selectedPrinter;
//   PaperSize selectedPaperSize = PaperSize.mm58;

//   // Receipt data
//   bool _isLoading = true;
//   String shopName = 'N/A';
//   String contact = 'N/A';
//   String address = 'N/A';

//   double calculateTotal(List<Map<String, dynamic>> selectedItemsDetails) {
//     double total = 0;
//     for (var itemDetails in selectedItemsDetails) {
//       double price = itemDetails['price'] ?? 0;
//       int quantity = itemDetails['quantity'] ?? 0;
//       total += price * quantity;
//     }
//     return total;
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
//     _portController.text = _port;

//     // Load shop data first
//     _loadShopData();

//     // subscription to listen change status of bluetooth connection
//     _subscriptionBtStatus =
//         PrinterManager.instance.stateBluetooth.listen((status) {
//       log(' ----------------- status bt $status ------------------ ');
//       _currentStatus = status;
//       if (status == BTStatus.connected) {
//         setState(() {
//           _isConnected = true;
//         });
//       }
//       if (status == BTStatus.none) {
//         setState(() {
//           _isConnected = false;
//         });
//       }
//       if (status == BTStatus.connected && pendingTask != null) {
//         if (Platform.isAndroid) {
//           Future.delayed(const Duration(milliseconds: 1000), () {
//             PrinterManager.instance
//                 .send(type: PrinterType.bluetooth, bytes: pendingTask!);
//             pendingTask = null;
//           });
//         } else if (Platform.isIOS) {
//           PrinterManager.instance
//               .send(type: PrinterType.bluetooth, bytes: pendingTask!);
//           pendingTask = null;
//         }
//       }
//     });

//     _subscriptionUsbStatus = PrinterManager.instance.stateUSB.listen((status) {
//       log(' ----------------- status usb $status ------------------ ');
//       _currentUsbStatus = status;
//       if (Platform.isAndroid) {
//         if (status == USBStatus.connected && pendingTask != null) {
//           Future.delayed(const Duration(milliseconds: 1000), () {
//             PrinterManager.instance
//                 .send(type: PrinterType.usb, bytes: pendingTask!);
//             pendingTask = null;
//           });
//         }
//       }
//     });
//   }

//   Future<void> _loadShopData() async {
//     try {
//       final doc = await FirebaseFirestore.instance
//           .collection('AllAdmins')
//           .doc(widget.adminUid)
//           .collection('customer')
//           .doc(widget.userId)
//           .get();

//       if (doc.exists) {
//         final data = doc.data();
//         if (data != null) {
//           setState(() {
//             shopName = data['shopName'] ?? 'N/A';
//             contact = data['contact'] ?? 'N/A';
//             address = data['address'] ?? 'N/A';
//           });
//         }
//       }
//     } catch (e) {
//       print('Error fetching receipt data: $e');
//       // Continue with default values if fetch fails
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//       // Start scanning for printers after data is loaded
//       _scan();
//     }
//   }

//   @override
//   void dispose() {
//     _subscription?.cancel();
//     _subscriptionBtStatus?.cancel();
//     _subscriptionUsbStatus?.cancel();
//     _portController.dispose();
//     _ipController.dispose();
//     super.dispose();
//   }

//   void _scan() {
//     devices.clear();
//     _subscription = printerManager
//         .discovery(type: defaultPrinterType, isBle: _isBle)
//         .listen((device) {
//       devices.add(BluetoothPrinter(
//         deviceName: device.name,
//         address: device.address,
//         isBle: _isBle,
//         vendorId: device.vendorId,
//         productId: device.productId,
//         typePrinter: defaultPrinterType,
//       ));
//       setState(() {});
//     });
//   }

//   void setPort(String value) {
//     if (value.isEmpty) value = '9100';
//     _port = value;
//     var device = BluetoothPrinter(
//       deviceName: value,
//       address: _ipAddress,
//       port: _port,
//       typePrinter: PrinterType.network,
//       state: false,
//     );
//     selectDevice(device);
//   }

//   void setIpAddress(String value) {
//     _ipAddress = value;
//     var device = BluetoothPrinter(
//       deviceName: value,
//       address: _ipAddress,
//       port: _port,
//       typePrinter: PrinterType.network,
//       state: false,
//     );
//     selectDevice(device);
//   }

//   void selectDevice(BluetoothPrinter device) async {
//     if (selectedPrinter != null) {
//       if ((device.address != selectedPrinter!.address) ||
//           (device.typePrinter == PrinterType.usb &&
//               selectedPrinter!.vendorId != device.vendorId)) {
//         await PrinterManager.instance
//             .disconnect(type: selectedPrinter!.typePrinter);
//       }
//     }

//     selectedPrinter = device;
//     setState(() {});
//   }

//   Future<List<int>> addLogoToBytes(
//       Generator generator, bool is58mm, List<int> bytes) async {
//     // Load image from assets
//     ByteData data = await rootBundle.load('assets/images/logo.jpg');
//     Uint8List logoBytes = data.buffer.asUint8List();

//     // Decode to Image object
//     img.Image? logoImage = img.decodeImage(logoBytes);
//     if (logoImage != null) {
//       // Set width according to paper size
//       int targetWidth = is58mm ? 200 : 400;
//       int targetHeight =
//           (logoImage.height * targetWidth / logoImage.width).round();

//       // Resize the image
//       img.Image resizedLogo = img.copyResize(
//         logoImage,
//         width: targetWidth,
//         height:
//             targetHeight, // remove this line if you want to preserve aspect ratio automatically
//       );

//       // Add to bytes
//       bytes += generator.imageRaster(
//         resizedLogo,
//         align: PosAlign.center,
//       );
//     }

//     return bytes;
//   }

//   Future<void> _printReceiveTest() async {
//     try {
//       final profile = await CapabilityProfile.load(name: 'XP-N160I');
//       final Generator generator = Generator(selectedPaperSize, profile);

//       List<int> bytes = [];

//       bytes += generator.setGlobalCodeTable('CP1252');

//       // Paper configuration
//       bool is58mm = selectedPaperSize == PaperSize.mm58;
//       int totalCols = is58mm ? 31 : 48;
//       String separator = '*' * totalCols;

//       // Smart dynamic columns
//       int desc = is58mm ? 12 : 22;
//       int qty = is58mm ? 5 : 6;
//       int rate = is58mm ? 6 : 8;
//       int amt = is58mm ? 7 : 10;

//       // Small font style
//       const smallFontCenter = PosStyles(
//         align: PosAlign.center,
//       );

//       const smallFontLeft = PosStyles(
//         align: PosAlign.left,
//       );

//       // bytes = await addLogoToBytes(generator, is58mm, bytes);

//       // Header
//       bytes += generator.text(shopName, styles: smallFontCenter);
//       bytes += generator.text(address, styles: smallFontCenter);
//       bytes += generator.text('$contact', styles: smallFontCenter);
//       bytes += generator.text(
//           DateFormat('dd-MM-yyyy | hh:mm a').format(DateTime.now()),
//           styles: smallFontCenter);

//       bytes += generator.text(separator, styles: smallFontLeft);

//       bytes += generator.text('RECEIPT', styles: smallFontCenter);
//       bytes += generator.text(separator, styles: smallFontLeft);

//       // Table header
//       bytes += generator.text(
//         '${"Description".padRight(desc)}'
//         '${"Qty".padLeft(qty)}'
//         '${"Rate".padLeft(rate)}'
//         '${"Amt".padLeft(amt)}',
//         styles: smallFontLeft,
//       );

//       // Items
//       for (var item in widget.selectedItemsDetails) {
//         String name = item['name'].toString();
//         if (name.length > desc) {
//           name = name.substring(0, desc - 3) + "..."; // ASCII ellipsis
//         }

//         int qtyValue = int.tryParse(item['quantity'].toString()) ?? 1;
//         double rateValue = double.tryParse(item['price'].toString()) ?? 0;
//         double amtValue = qtyValue * rateValue;

//         bytes += generator.text(
//           '${name.padRight(desc)}'
//           '${qtyValue.toString().padLeft(qty)}'
//           '${rateValue.toStringAsFixed(2).padLeft(rate)}'
//           '${amtValue.toStringAsFixed(2).padLeft(amt)}',
//           styles: smallFontLeft,
//         );
//       }

//       // Calculate GST
//       double subtotal = widget.total ?? 0;
//       double cgst = subtotal * 0.025; // 2.5% CGST
//       double sgst = subtotal * 0.025; // 2.5% SGST
//       double grandTotal = subtotal + cgst + sgst;

//       // Subtotal
//       bytes += generator.text(separator, styles: smallFontLeft);
//       bytes += generator.text(
//         'SUBTOTAL'.padRight(totalCols - 8) +
//             subtotal.toStringAsFixed(2).padLeft(8),
//         styles: smallFontLeft,
//       );

//       // CGST
//       bytes += generator.text(
//         'CGST (2.5%)'.padRight(totalCols - 8) +
//             cgst.toStringAsFixed(2).padLeft(8),
//         styles: smallFontLeft,
//       );

//       // SGST
//       bytes += generator.text(
//         'SGST (2.5%)'.padRight(totalCols - 8) +
//             sgst.toStringAsFixed(2).padLeft(8),
//         styles: smallFontLeft,
//       );

//       // Grand Total
//       bytes += generator.text(separator, styles: smallFontLeft);
//       bytes += generator.text(
//         'GRAND TOTAL'.padRight(totalCols - 8) +
//             grandTotal.toStringAsFixed(2).padLeft(8),
//         styles: smallFontLeft,
//       );

//       // Footer
//       bytes += generator.text(separator, styles: smallFontLeft);
//       bytes +=
//           generator.text('Thank you! Visit Again', styles: smallFontCenter);
//       bytes += generator.cut();

//       await _printEscPos(bytes, generator);
//     } catch (e) {
//       debugPrint("Printing error: $e");
//     }
//   }

//   Future<void> _printEscPos(
//     List<int> bytes,
//     Generator generator,
//   ) async {
//     final printprovider = Provider.of<PrintProvider>(context, listen: false);
//     if (selectedPrinter == null) return;
//     var bluetoothPrinter = selectedPrinter!;
//     try {
//       switch (bluetoothPrinter.typePrinter) {
//         case PrinterType.usb:
//           await printerManager.connect(
//               type: bluetoothPrinter.typePrinter,
//               model: UsbPrinterInput(
//                   name: bluetoothPrinter.deviceName,
//                   productId: bluetoothPrinter.productId,
//                   vendorId: bluetoothPrinter.vendorId));
//           pendingTask = null;
//           break;
//         case PrinterType.bluetooth:
//           await printerManager.connect(
//               type: bluetoothPrinter.typePrinter,
//               model: BluetoothPrinterInput(
//                   name: bluetoothPrinter.deviceName,
//                   address: bluetoothPrinter.address!,
//                   isBle: bluetoothPrinter.isBle ?? false,
//                   autoConnect: _reconnect));

//           break;
//         case PrinterType.network:
//           await printerManager.connect(
//               type: bluetoothPrinter.typePrinter,
//               model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!));
//           break;
//         default:
//       }
//       await printerManager.send(
//           type: bluetoothPrinter.typePrinter, bytes: bytes);
//       printprovider.clearCart();
//     } catch (e) {
//       print('Printing error: $e');
//     }
//   }

//   Widget buildPaperSizeSelector() {
//     return DropdownButtonFormField<PaperSize>(
//       value: selectedPaperSize,
//       decoration: const InputDecoration(
//         prefixIcon: Icon(
//           Icons.receipt_long,
//           size: 24,
//         ),
//         labelText: "Paper Size",
//         labelStyle: TextStyle(fontSize: 18.0),
//         focusedBorder: InputBorder.none,
//         enabledBorder: InputBorder.none,
//       ),
//       items: const <DropdownMenuItem<PaperSize>>[
//         DropdownMenuItem(
//           value: PaperSize.mm58,
//           child: Text("58mm"),
//         ),
//         DropdownMenuItem(
//           value: PaperSize.mm80,
//           child: Text("80mm"),
//         ),
//       ],
//       onChanged: (PaperSize? value) {
//         if (value != null) {
//           setState(() {
//             selectedPaperSize = value;
//           });
//         }
//       },
//     );
//   }

//   _connectDevice() async {
//     _isConnected = false;
//     if (selectedPrinter == null) return;
//     switch (selectedPrinter!.typePrinter) {
//       case PrinterType.usb:
//         await printerManager.connect(
//             type: selectedPrinter!.typePrinter,
//             model: UsbPrinterInput(
//                 name: selectedPrinter!.deviceName,
//                 productId: selectedPrinter!.productId,
//                 vendorId: selectedPrinter!.vendorId));
//         _isConnected = true;
//         break;
//       case PrinterType.bluetooth:
//         await printerManager.connect(
//             type: selectedPrinter!.typePrinter,
//             model: BluetoothPrinterInput(
//                 name: selectedPrinter!.deviceName,
//                 address: selectedPrinter!.address!,
//                 isBle: selectedPrinter!.isBle ?? false,
//                 autoConnect: _reconnect));
//         break;
//       case PrinterType.network:
//         await printerManager.connect(
//             type: selectedPrinter!.typePrinter,
//             model: TcpPrinterInput(ipAddress: selectedPrinter!.address!));
//         _isConnected = true;
//         break;
//       default:
//     }

//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     final printprovider = Provider.of<PrintProvider>(
//       context,
//     );
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Print Receipt'),
//       ),
//       body: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(),
//             )
//           : Center(
//               child: Container(
//                 height: double.infinity,
//                 constraints: const BoxConstraints(maxWidth: 400),
//                 child: SingleChildScrollView(
//                   padding: EdgeInsets.zero,
//                   child: Column(
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: buildPaperSizeSelector(),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Row(
//                           children: [
//                             Expanded(
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   foregroundColor: Colors.black,
//                                   backgroundColor:
//                                       const Color.fromARGB(255, 125, 237, 155),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(30),
//                                   ),
//                                 ),
//                                 onPressed:
//                                     selectedPrinter == null || _isConnected
//                                         ? null
//                                         : () {
//                                             _connectDevice();
//                                           },
//                                 child: const Text("Connect",
//                                     textAlign: TextAlign.center),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   foregroundColor: Colors.black,
//                                   backgroundColor:
//                                       const Color.fromARGB(255, 125, 237, 155),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(30),
//                                   ),
//                                 ),
//                                 onPressed: selectedPrinter == null ||
//                                         !_isConnected
//                                     ? null
//                                     : () {
//                                         if (selectedPrinter != null) {
//                                           printerManager.disconnect(
//                                               type:
//                                                   selectedPrinter!.typePrinter);
//                                         }
//                                         setState(() {
//                                           _isConnected = false;
//                                         });
//                                       },
//                                 child: const Text("Disconnect",
//                                     textAlign: TextAlign.center),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       DropdownButtonFormField<PrinterType>(
//                         value: defaultPrinterType,
//                         decoration: const InputDecoration(
//                           prefixIcon: Icon(
//                             Icons.print,
//                             size: 24,
//                           ),
//                           labelText: "Type Printer Device",
//                           labelStyle: TextStyle(fontSize: 18.0),
//                           focusedBorder: InputBorder.none,
//                           enabledBorder: InputBorder.none,
//                         ),
//                         items: <DropdownMenuItem<PrinterType>>[
//                           if (Platform.isAndroid || Platform.isIOS)
//                             const DropdownMenuItem(
//                               value: PrinterType.bluetooth,
//                               child: Text("bluetooth"),
//                             ),
//                           if (Platform.isAndroid || Platform.isWindows)
//                             const DropdownMenuItem(
//                               value: PrinterType.usb,
//                               child: Text("usb"),
//                             ),
//                           const DropdownMenuItem(
//                             value: PrinterType.network,
//                             child: Text("Wifi"),
//                           ),
//                         ],
//                         onChanged: (PrinterType? value) {
//                           setState(() {
//                             if (value != null) {
//                               setState(() {
//                                 defaultPrinterType = value;
//                                 selectedPrinter = null;
//                                 _isBle = false;
//                                 _isConnected = false;
//                                 _scan();
//                               });
//                             }
//                           });
//                         },
//                       ),
//                       Visibility(
//                         visible: defaultPrinterType == PrinterType.bluetooth &&
//                             Platform.isAndroid,
//                         child: SwitchListTile.adaptive(
//                           contentPadding:
//                               const EdgeInsets.only(bottom: 20.0, left: 20),
//                           title: const Text(
//                             "reconnect",
//                             textAlign: TextAlign.start,
//                             style: TextStyle(fontSize: 19.0),
//                           ),
//                           value: _reconnect,
//                           onChanged: (bool? value) {
//                             setState(() {
//                               _reconnect = value ?? false;
//                             });
//                           },
//                         ),
//                       ),
//                       Column(
//                           children: devices
//                               .map(
//                                 (device) => ListTile(
//                                   title: Text('${device.deviceName}'),
//                                   subtitle: Platform.isAndroid &&
//                                           defaultPrinterType == PrinterType.usb
//                                       ? null
//                                       : Visibility(
//                                           visible: !Platform.isWindows,
//                                           child: Text("${device.address}")),
//                                   onTap: () {
//                                     selectDevice(device);
//                                   },
//                                   leading: selectedPrinter != null &&
//                                           ((device.typePrinter ==
//                                                           PrinterType.usb &&
//                                                       Platform.isWindows
//                                                   ? device.deviceName ==
//                                                       selectedPrinter!
//                                                           .deviceName
//                                                   : device.vendorId != null &&
//                                                       selectedPrinter!
//                                                               .vendorId ==
//                                                           device.vendorId) ||
//                                               (device.address != null &&
//                                                   selectedPrinter!.address ==
//                                                       device.address))
//                                       ? const Icon(
//                                           Icons.check,
//                                           color: Colors.green,
//                                         )
//                                       : null,
//                                   trailing: OutlinedButton(
//                                     onPressed: selectedPrinter == null ||
//                                             device.deviceName !=
//                                                 selectedPrinter?.deviceName
//                                         ? null
//                                         : () async {
//                                             _printReceiveTest();
//                                             printprovider.clearCart();
//                                             Navigator.pop(context);
//                                           },
//                                     child: const Padding(
//                                       padding: EdgeInsets.symmetric(
//                                           vertical: 2, horizontal: 20),
//                                       child: Text("Print Receipt",
//                                           textAlign: TextAlign.center),
//                                     ),
//                                   ),
//                                 ),
//                               )
//                               .toList()),
//                       Visibility(
//                         visible: defaultPrinterType == PrinterType.network &&
//                             Platform.isWindows,
//                         child: Padding(
//                           padding: const EdgeInsets.only(top: 10.0),
//                           child: TextFormField(
//                             controller: _ipController,
//                             keyboardType: const TextInputType.numberWithOptions(
//                                 signed: true),
//                             decoration: const InputDecoration(
//                               label: Text("Ip Address"),
//                               prefixIcon: Icon(Icons.wifi, size: 24),
//                             ),
//                             onChanged: setIpAddress,
//                           ),
//                         ),
//                       ),
//                       Visibility(
//                         visible: defaultPrinterType == PrinterType.network &&
//                             Platform.isWindows,
//                         child: Padding(
//                           padding: const EdgeInsets.only(top: 10.0),
//                           child: TextFormField(
//                             controller: _portController,
//                             keyboardType: const TextInputType.numberWithOptions(
//                                 signed: true),
//                             decoration: const InputDecoration(
//                               label: Text("Port"),
//                               prefixIcon:
//                                   Icon(Icons.numbers_outlined, size: 24),
//                             ),
//                             onChanged: setPort,
//                           ),
//                         ),
//                       ),
//                       Visibility(
//                         visible: defaultPrinterType == PrinterType.network &&
//                             Platform.isWindows,
//                         child: Padding(
//                           padding: const EdgeInsets.only(top: 10.0),
//                           child: OutlinedButton(
//                             onPressed: () async {
//                               if (_ipController.text.isNotEmpty) {
//                                 setIpAddress(_ipController.text);
//                               }
//                               _printReceiveTest();
//                               printprovider.clearCart();
//                             },
//                             child: const Padding(
//                               padding: EdgeInsets.symmetric(
//                                   vertical: 4, horizontal: 50),
//                               child: Text("Print test ticket",
//                                   textAlign: TextAlign.center),
//                             ),
//                           ),
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//     );
//   }
// }

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:intl/intl.dart';
import 'package:pos/view/home/print_provider.dart';
import 'package:pos/view/tab_screen/view-model/backend/offline_bill_manager.dart';
import 'package:pos/view/tab_screen/view-model/backend/connection_monitor.dart';

class DirectPrintHelper {
  // Generate 8-digit random receipt number
  static String generateReceiptNumber() {
    final random = Random();
    return (10000000 + random.nextInt(90000000)).toString();
  }

  static Future<void> printReceipt({
    required BuildContext context,
    required BluetoothPrinter printer,
    required PaperSize paperSize,
    required List<Map<String, dynamic>> items,
    required double total,
    required String shopName,
    required String contact,
    required String address,
    required String adminUid,
    String? tableNumber,
    bool taxEnabled = false,
    double cgstPercent = 2.5,
    double sgstPercent = 2.5,
  }) async {
    try {
      // Generate receipt number
      final String receiptNo = generateReceiptNumber();

      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final Generator generator = Generator(paperSize, profile);

      List<int> bytes = [];
      bytes += generator.setGlobalCodeTable('CP1252');

      // Paper configuration
      bool is58mm = paperSize == PaperSize.mm58;
      int totalCols = is58mm ? 31 : 48;
      String separator = '*' * totalCols;

      // Smart dynamic columns
      int desc = is58mm ? 12 : 22;
      int qty = is58mm ? 5 : 6;
      int rate = is58mm ? 6 : 8;
      int amt = is58mm ? 7 : 10;

      // Small font style
      const smallFontCenter = PosStyles(align: PosAlign.center);
      const smallFontLeft = PosStyles(align: PosAlign.left);

      // Header
      bytes += generator.text(shopName, styles: smallFontCenter);
      bytes += generator.text(address, styles: smallFontCenter);
      bytes += generator.text(contact, styles: smallFontCenter);
      bytes += generator.text(
        DateFormat('dd-MM-yyyy | hh:mm a').format(DateTime.now()),
        styles: smallFontCenter,
      );

      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text('RECEIPT', styles: smallFontCenter);
      bytes +=
          generator.text('Receipt No: $receiptNo', styles: smallFontCenter);

      // Table number (show N/A if not provided)
      if (tableNumber != null || tableNumber != 'N/A') {
        bytes += generator.text(
          'Table No: ${tableNumber ?? 'N/A'}',
          styles: smallFontCenter,
        );
      }

      bytes += generator.text(separator, styles: smallFontLeft);

      // Table header
      bytes += generator.text(
        '${"Description".padRight(desc)}'
        '${"Qty".padLeft(qty)}'
        '${"Rate".padLeft(rate)}'
        '${"Amt".padLeft(amt)}',
        styles: smallFontLeft,
      );

      // Items
      for (var item in items) {
        String name = item['name'].toString();
        if (name.length > desc) {
          name = name.substring(0, desc - 3) + "...";
        }

        int qtyValue = int.tryParse(item['quantity'].toString()) ?? 1;
        double rateValue = double.tryParse(item['price'].toString()) ?? 0;
        double amtValue = qtyValue * rateValue;

        bytes += generator.text(
          '${name.padRight(desc)}'
          '${qtyValue.toString().padLeft(qty)}'
          '${rateValue.toStringAsFixed(2).padLeft(rate)}'
          '${amtValue.toStringAsFixed(2).padLeft(amt)}',
          styles: smallFontLeft,
        );
      }

      // Calculate totals
      double subtotal = total;
      double grandTotal = subtotal;

      // Subtotal
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        'SUBTOTAL'.padRight(totalCols - 8) +
            subtotal.toStringAsFixed(2).padLeft(8),
        styles: smallFontLeft,
      );

      // Only show tax if enabled
      if (taxEnabled) {
        double cgst = subtotal * (cgstPercent / 100);
        double sgst = subtotal * (sgstPercent / 100);
        grandTotal = subtotal + cgst + sgst;

        // CGST
        bytes += generator.text(
          'CGST (${cgstPercent.toStringAsFixed(1)}%)'.padRight(totalCols - 8) +
              cgst.toStringAsFixed(2).padLeft(8),
          styles: smallFontLeft,
        );

        // SGST
        bytes += generator.text(
          'SGST (${sgstPercent.toStringAsFixed(1)}%)'.padRight(totalCols - 8) +
              sgst.toStringAsFixed(2).padLeft(8),
          styles: smallFontLeft,
        );
      }

      // Grand Total
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        'GRAND TOTAL'.padRight(totalCols - 8) +
            grandTotal.toStringAsFixed(2).padLeft(8),
        styles: smallFontLeft,
      );

      // Footer
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes +=
          generator.text('Thank you! Visit Again', styles: smallFontCenter);
      bytes += generator.cut();

      // Send to printer
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      // Check if online before saving
      final isConnected = await isOnline();

      // Save bill data to Firebase (or offline)
      await saveBillToFirebase(
        adminUid: adminUid,
        receiptNo: receiptNo,
        items: items,
        subTotal: subtotal,
      );

      if (context.mounted) {
        final message = isConnected
            ? 'Receipt printed & saved online! Receipt No: $receiptNo'
            : 'Receipt printed & saved offline! Will sync when online. Receipt No: $receiptNo';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isConnected ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Printing error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> saveBillToFirebase({
    required String adminUid,
    required String receiptNo,
    required List<Map<String, dynamic>> items,
    required double subTotal,
  }) async {
    try {
      // Check connectivity
      final connectionMonitor = ConnectionMonitor();
      await connectionMonitor.initialize();
      final isConnected = connectionMonitor.isConnected;

      final now = DateTime.now();
      final monthDoc = DateFormat('yyyyMM').format(now); // e.g., "202512"
      final dateDoc = DateFormat('yyyyMMdd').format(now); // e.g., "20251209"
      final dateString =
          DateFormat('MMM dd, yyyy').format(now); // e.g., "Dec 09, 2025"

      // Prepare items array - ensure each item has name, price, quantity
      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'name': item['name'] ?? '',
          'price': double.tryParse(item['price'].toString()) ?? 0.0,
          'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
        };
      }).toList();

      // Prepare bill data
      final billData = {
        'id': receiptNo,
        'adminId': adminUid,
        'date': dateString,
        'items': itemsData,
        'receiptNo': receiptNo,
        'subTotal': subTotal,
        'monthDoc': monthDoc,
        'dateDoc': dateDoc,
        'createdAt': now.toString(),
      };

      if (isConnected) {
        // Save to Firebase online
        await FirebaseFirestore.instance
            .collection('AllBills')
            .doc(adminUid)
            .collection('myBills')
            .doc(monthDoc)
            .collection(dateDoc)
            .doc(receiptNo)
            .set({
          'adminId': adminUid,
          'createdAt': FieldValue.serverTimestamp(),
          'date': dateString,
          'items': itemsData,
          'receiptNo': receiptNo,
          'subTotal': subTotal,
        });

        debugPrint('Bill saved to Firebase successfully (online)');
      } else {
        // Save offline using OfflineBillManager
        final offlineBillManager = OfflineBillManager();
        await offlineBillManager.initialize();
        await offlineBillManager.storeBillOffline(adminUid, billData);

        debugPrint('Bill saved offline successfully - will sync when online');
      }

      connectionMonitor.dispose();
    } catch (e) {
      debugPrint('Error saving bill: $e');

      // Fallback to offline storage if online save fails
      try {
        final now = DateTime.now();
        final dateString = DateFormat('MMM dd, yyyy').format(now);
        final monthDoc = DateFormat('yyyyMM').format(now);
        final dateDoc = DateFormat('yyyyMMdd').format(now);

        final itemsData = items.map((item) {
          return {
            'name': item['name'] ?? '',
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
          };
        }).toList();

        final billData = {
          'id': receiptNo,
          'adminId': adminUid,
          'date': dateString,
          'items': itemsData,
          'receiptNo': receiptNo,
          'subTotal': subTotal,
          'monthDoc': monthDoc,
          'dateDoc': dateDoc,
          'createdAt': now.millisecondsSinceEpoch,
        };

        final offlineBillManager = OfflineBillManager();
        await offlineBillManager.initialize();
        await offlineBillManager.storeBillOffline(adminUid, billData);

        debugPrint('Bill saved offline as fallback after online failure');
      } catch (offlineError) {
        debugPrint('Failed to save bill offline: $offlineError');
        rethrow;
      }
    }
  }

  static Future<void> printReceiptWithProvider({
    required BuildContext context,
    required PrintProvider printProvider,
    required String adminUid,
    required String userId,
  }) async {
    // Check if printer is connected
    if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a printer first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if there are items to print
    if (printProvider.posts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Fetch shop data
      final doc = await FirebaseFirestore.instance
          .collection('AllAdmins')
          .doc(adminUid)
          .collection('customer')
          .doc(userId)
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

      // Print receipt
      await printReceipt(
        adminUid: adminUid,
        context: context,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: printProvider.posts,
        total: printProvider.total,
        shopName: shopName,
        contact: contact,
        address: address,
      );

      // Clear cart after successful print
      printProvider.clearCart();
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get offline bill statistics for display
  static Future<Map<String, dynamic>> getOfflineBillStats(
      String adminUid) async {
    try {
      final offlineBillManager = OfflineBillManager();
      await offlineBillManager.initialize();
      return await offlineBillManager
          .getDetailedOfflineBillStatistics(adminUid);
    } catch (e) {
      debugPrint('Error getting offline bill stats: $e');
      return {
        'error': e.toString(),
        'offlineBillsCount': 0,
      };
    }
  }

  /// Manually trigger sync of offline bills
  static Future<OfflineBillSyncResult> syncOfflineBills(String adminUid) async {
    try {
      final offlineBillManager = OfflineBillManager();
      await offlineBillManager.initialize();
      return await offlineBillManager.manualSyncOfflineBills(adminUid);
    } catch (e) {
      debugPrint('Error syncing offline bills: $e');
      return OfflineBillSyncResult(
        success: false,
        errorMessage: e.toString(),
        billsSynced: 0,
      );
    }
  }

  /// Check if device is currently online
  static Future<bool> isOnline() async {
    try {
      final connectionMonitor = ConnectionMonitor();
      await connectionMonitor.initialize();
      final isConnected = connectionMonitor.isConnected;
      connectionMonitor.dispose();
      return isConnected;
    } catch (e) {
      debugPrint('Error checking online status: $e');
      return false;
    }
  }
}

class BluetoothPrinter {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;

  PrinterType typePrinter;
  bool? state;

  BluetoothPrinter(
      {this.deviceName,
      this.address,
      this.port,
      this.state,
      this.vendorId,
      this.productId,
      this.typePrinter = PrinterType.bluetooth,
      this.isBle = false});
}
