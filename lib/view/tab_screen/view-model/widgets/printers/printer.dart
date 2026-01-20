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

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:image/image.dart' as img_lib;
import 'package:http/http.dart' as http;

import '../../../../../core/network/connection_monitor.dart';
import '../../../../../data/datasources/offline_bill_manager.dart';

class DirectPrintHelper {
  // Generate 8-digit random receipt number

  static String generateReceiptNumber() {
    final random = Random();
    return (10000000 + random.nextInt(90000000)).toString();
  }

  final SmartDatabaseService _databaseService = SmartDatabaseService();

  static Future<List<int>> loadLogoOfflineSafe(
    String logoUrl,
    Generator generator,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/printer_logo.png');

      img_lib.Image? image;

      // ✅ 1. If file exists → use it (OFFLINE SAFE)
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        image = img_lib.decodeImage(bytes);
      }

      // ✅ 2. If file missing → try downloading (ONLINE ONLY)
      if (image == null && logoUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          image = img_lib.decodeImage(response.bodyBytes);
        }
      }

      if (image == null) return [];

      // 🔧 Printer-friendly resize + grayscale
      final resized = img_lib.copyResize(image, width: 200);
      final mono = img_lib.grayscale(resized);

      return generator.imageRaster(
        mono,
        align: PosAlign.center,
      );
    } catch (e) {
      debugPrint("Logo offline load failed: $e");
      return [];
    }
  }

  Future<void> printReceipt({
    required BuildContext context,
    required BluetoothPrinter printer,
    required PaperSize paperSize,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required String shopName,
    required String logoUrl,
    required String contact,
    required String address,
    required String adminUid,
    String? tableNumber,
    String? receiptNo,
    bool taxEnabled = false,
    double cgstPercent = 0.0,
    double sgstPercent = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerGst,
    String? customerAddress,
    String? customerNote,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
    String? paymentType,
    String? orderType,
    bool saveBill = false,
  }) async {
    try {
      // Use provided receipt number or generate a new one
      final String finalReceiptNo = receiptNo ?? generateReceiptNumber();

      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final Generator generator = Generator(paperSize, profile);

      List<int> bytes = [];
      bytes += generator.setGlobalCodeTable('CP737');

      List<String> wrapTextByWords(String text, int maxWidth) {
        List<String> lines = [];
        List<String> words = text.split(' ');
        String currentLine = '';

        for (final word in words) {
          if ((currentLine + word).length <= maxWidth) {
            currentLine += (currentLine.isEmpty ? '' : ' ') + word;
          } else {
            lines.add(currentLine);
            currentLine = word;
          }
        }

        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }

        return lines;
      }

      // Paper configuration
      bool is58mm = paperSize == PaperSize.mm58;
      int totalCols = is58mm ? 32 : 48;
      String separator = '-' * totalCols;
      int totalQty = 0;
      double addonsTotal = 0;

      // Smart dynamic columns
      int desc = is58mm ? 13 : 22;
      int qty = is58mm ? 4 : 6;
      int rate = is58mm ? 6 : 8;
      int amt = is58mm ? 7 : 10;

      // Small font style
      const smallFontCenter = PosStyles(align: PosAlign.center);
      const smallFontLeft = PosStyles(align: PosAlign.left);

      // Header

      if (logoUrl.isNotEmpty) {
        // final logoBytes = await _loadLogoForPrinter(logoUrl, generator);
        final logoBytes = await loadLogoOfflineSafe(logoUrl, generator);

        bytes += logoBytes;
        bytes += generator.feed(1);
      }
      bytes += generator.emptyLines(1);
      bytes += generator.text(shopName,
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.text(address, styles: smallFontCenter);
      bytes += generator.text("Mob.No : $contact", styles: smallFontCenter);
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        "Date : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
        styles: smallFontLeft,
      );
      bytes += generator.text(
        "Time : ${DateFormat('hh:mm a').format(DateTime.now())}",
        styles: smallFontLeft,
      );
      bytes += generator.text(
        "Receipt No : $finalReceiptNo",
        styles: smallFontLeft,
      );

      // // Table number (show N/A if not provided)
      if (tableNumber != null && tableNumber.isNotEmpty) {
        bytes += generator.text(
          'Table No: $tableNumber ',
          styles: smallFontLeft,
        );
      }
      if (customerName != null && customerName.isNotEmpty) bytes += generator.text(separator, styles: smallFontLeft);
      if (customerName != null && customerName.isNotEmpty) {
        bytes += generator.text(
          "Name :  $customerName",
          styles: smallFontLeft,
        );
      }

      if (customerPhone != null && customerPhone.isNotEmpty) {
        bytes += generator.text(
          "Phone : $customerPhone",
          styles: smallFontLeft,
        );
      }

      bytes += generator.text(separator, styles: smallFontLeft);

      // Table header
      bytes += generator.text(
        '${"Item".padRight(desc)}'
        '${"Qty".padLeft(qty)}'
        '${"Price".padLeft(rate)}'
        '${"Amt".padLeft(amt)}',
        styles: smallFontLeft,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      String fmt(num v) {
        if (v % 1 == 0) return v.toInt().toString();
        return v.toStringAsFixed(2);
      }

      // Items
      for (var item in items) {
        String name = item['name'].toString();
        List<String> nameLines = wrapTextByWords(name, desc);

        int qtyValue = int.tryParse(item['quantity'].toString()) ?? 1;
        double rateValue = double.tryParse(item['price'].toString()) ?? 0;
        double amtValue = qtyValue * rateValue;
        totalQty += qtyValue;

        bytes += generator.text(
          '${nameLines.first.padRight(desc)}'
          '${"x ${qtyValue.toString()}".padLeft(qty)}'
          '${fmt(rateValue).padLeft(rate)}'
          '${amtValue.toString().padLeft(amt)}',
          styles: smallFontLeft,
        );

        for (int i = 1; i < nameLines.length; i++) {
          bytes += generator.text(
            '${nameLines[i].padRight(desc)}'
            '${"".padLeft(qty)}'
            '${"".padLeft(rate)}'
            '${"".padLeft(amt)}',
            styles: smallFontLeft,
          );
        }
        if (item['addons'] != null && (item['addons'] as List).isNotEmpty) {
          for (var addon in item['addons']) {
            String addonName = " ${addon['name']}";
            if (addonName.length > desc) {
              addonName = "${addonName.substring(0, desc - 3)}...";
            }

            double addonPrice = double.tryParse(addon['price'].toString()) ?? 0;
            addonsTotal += addonPrice * qtyValue;

            bytes += generator.text(
              '${addonName.padRight(desc)}'
              '${"".padLeft(qty)}'
              '${fmt(addonPrice).padLeft(rate)}'
              '${"".padLeft(amt)}',
              styles: smallFontLeft,
            );
          }
        }
      }

      // Calculate totals
      double subtotal = subTotal;
      double addons = addonsTotal;
      double taxTotal = 0;
      double grandTotal = subtotal + addons;

      // Total Qty
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        'TOTAL QTY'.padRight(totalCols - 8) + totalQty.toString().padLeft(8),
        styles: smallFontLeft,
      );

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
        taxTotal = cgst + sgst;
        grandTotal += taxTotal;

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
      if (addonsTotal > 0) {
        bytes += generator.text(
            'ADD-ONS'.padRight(totalCols - 8) + fmt(addonsTotal).padLeft(8));
      }

      // Grand Total
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text('GRAND TOTAL'.padRight(totalCols - 8) + fmt(grandTotal).padLeft(8),
          styles: const PosStyles(bold: true));
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text(
        "PAID [${paymentType!.toUpperCase()}]",
        styles: smallFontLeft,
      );

      if (customerNote != null && customerNote.isNotEmpty) {
        bytes += generator.text(separator, styles: smallFontLeft);

        bytes += generator.text(
          "CustomerNote :  $customerNote",
          styles: smallFontLeft,
        );
      }

      // 🔥 UPI QR
      String upiId = "richeyrichinfotech@icici";
      String upiUrl =
          "upi://pay?pa=$upiId&pn=$shopName&am=${fmt(grandTotal)}&cu=INR";

      bytes += generator.emptyLines(1);
      bytes +=
          generator.qrcode(upiUrl, size: QRSize.Size6, align: PosAlign.center);
      bytes += generator.emptyLines(1);

      // Footer
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes +=
          generator.text('Thank you! Visit Again', styles: smallFontCenter);
      bytes += generator.cut();

      final isConnected = await isOnline();

      // Send to printer
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      if (saveBill) {
        await saveBillData(
          adminUid: adminUid,
          receiptNo: finalReceiptNo,
          items: items,
          subTotal: subTotal,
          tableNumber: tableNumber,
          taxEnabled: taxEnabled,
          cgstPercent: cgstPercent,
          sgstPercent: sgstPercent,
          customerName: customerName,
          customerPhone: customerPhone,
          customerGst: customerGst,
          customerAddress: customerAddress,
          customerNote: customerNote,
          discountPercent: discountPercent,
          discountAmount: discountAmount,
          paymentType: paymentType,
          orderType: orderType,
        );
      }

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
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Receipt printed! Receipt No: $finalReceiptNo'),
        //     backgroundColor: Colors.green,
        //     duration: const Duration(seconds: 2),
        //   ),
        // );
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

  Future<void> saveBillData({
    required String adminUid,
    required String receiptNo,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    String? tableNumber,
    bool taxEnabled = false,
    double cgstPercent = 0.0,
    double sgstPercent = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerGst,
    String? customerAddress,
    String? customerNote,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
    String? paymentType,
    String? orderType,
  }) async {
    try {
      final now = DateTime.now();

      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'name': item['name'] ?? '',
          'price': double.tryParse(item['price'].toString()) ?? 0.0,
          'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
        };
      }).toList();

      // Calculate tax amounts if enabled
      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      double totalWithTax = subTotal;

      if (taxEnabled) {
        cgstAmount = subTotal * (cgstPercent / 100);
        sgstAmount = subTotal * (sgstPercent / 100);
        totalWithTax = subTotal + cgstAmount + sgstAmount;
      }

      // Calculate final total with discount
      double finalTotal = totalWithTax - discountAmount;

      // Prepare bill data for SmartDatabaseService
      // Note: items must be JSON encoded string for SQLite storage
      // Schema: id, admin_uid, customer_phone, items, total_amount, bill_date, created_at, updated_at, sync_status, firebase_id
      final billData = {
        'id': receiptNo,
        'bill_date': now.millisecondsSinceEpoch, // Store as integer for proper sorting
        'items': jsonEncode(itemsData), // Convert to JSON string for SQLite
        'total_amount': finalTotal,
        'sub_total': subTotal,
        'table_number': tableNumber ?? 'N/A',
        'tax_enabled': taxEnabled ? 1 : 0, // SQLite doesn't support bool, use int
        'cgst_percent': cgstPercent,
        'sgst_percent': sgstPercent,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'customer_name': customerName ?? '',
        'customer_phone': customerPhone ?? '',
        'customer_gst': customerGst ?? '',
        'customer_address': customerAddress ?? '',
        'customer_note': customerNote ?? '',
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'final_total': finalTotal,
        'payment_type': paymentType ?? '',
        'order_type': orderType ?? '',
      };

      // Save using SmartDatabaseService (handles online/offline automatically)
      // This already saves to Firebase when online, no need for separate Firebase call
      await _databaseService.saveBill(adminUid, billData);

      debugPrint(
          '[ReceiptPreview] Bill saved successfully - receiptNo: $receiptNo (${_databaseService.isOnline ? "online" : "offline"})');
    } catch (e) {
      debugPrint('Error saving bill: $e');
      rethrow;
    }
  }

  // static Future<void> saveBillToFirebase({
  //   required String adminUid,
  //   required String receiptNo,
  //   required List<Map<String, dynamic>> items,
  //   required double subTotal,
  //   required bool taxEnabled,
  //   required double cgstPercent,
  //   required double sgstPercent,
  //   required String customerName,
  //   required String customerPhone,
  //   required String customerGst,
  //   required String customerAddress,
  //   required String customerNote,
  //   required double discountPercent,
  //   required double discountAmount,
  //   required String paymentType,
  //   required String orderType,
  // }) async {
  //   try {
  //     // Check connectivity
  //     final connectionMonitor = ConnectionMonitor();
  //     await connectionMonitor.initialize();
  //     final isConnected = connectionMonitor.isConnected;

  //     final now = DateTime.now();
  //     final monthDoc = DateFormat('yyyyMM').format(now); // e.g., "202512"
  //     final dateDoc = DateFormat('yyyyMMdd').format(now); // e.g., "20251209"
  //     final dateString = DateFormat('MMM dd, yyyy').format(now); // e.g., "Dec 09, 2025"

  //     // Prepare items array - ensure each item has name, price, quantity
  //     final List<Map<String, dynamic>> itemsData = items.map((item) {
  //       return {
  //         'name': item['name'] ?? '',
  //         'price': double.tryParse(item['price'].toString()) ?? 0.0,
  //         'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
  //       };
  //     }).toList();

  //     final billData = {
  //       'id': receiptNo,
  //       'bill_date': now.millisecondsSinceEpoch, // Store as integer for proper sorting
  //       'items': itemsData,
  //       'total_amount': finalTotal,
  //       'sub_total': subTotal,
  //       'table_number': tableNumber ?? 'N/A',
  //       'tax_enabled': taxEnabled ? 1 : 0, // SQLite doesn't support bool, use int
  //       'cgst_percent': cgstPercent,
  //       'sgst_percent': sgstPercent,
  //       'cgst_amount': cgstAmount,
  //       'sgst_amount': sgstAmount,
  //       'customer_name': customerName ?? '',
  //       'customer_phone': customerPhone ?? '',
  //       'customer_gst': customerGst ?? '',
  //       'customer_address': customerAddress ?? '',
  //       'customer_note': customerNote ?? '',
  //       'discount_percent': discountPercent,
  //       'discount_amount': discountAmount,
  //       'final_total': finalTotal,
  //       'payment_type': paymentType ?? '',
  //       'order_type': orderType ?? '',
  //     };

  //     // Prepare bill data
  //     final billData = {
  //       'id': receiptNo,
  //       'adminId': adminUid,
  //       'date': dateString,
  //       'items': itemsData,
  //       'receiptNo': receiptNo,
  //       'subTotal': subTotal,
  //       'monthDoc': monthDoc,
  //       'dateDoc': dateDoc,
  //       'createdAt': now.toString(),
  //     };

  //     if (isConnected) {
  //       // Save to Firebase online
  //       await FirebaseFirestore.instance
  //           .collection('AllBills')
  //           .doc(adminUid)
  //           .collection('myBills')
  //           .doc(monthDoc)
  //           .collection(dateDoc)
  //           .doc(receiptNo)
  //           .set({
  //         'adminId': adminUid,
  //         'createdAt': FieldValue.serverTimestamp(),
  //         'date': dateString,
  //         'items': itemsData,
  //         'receiptNo': receiptNo,
  //         'subTotal': subTotal,
  //       });

  //       debugPrint('Bill saved to Firebase successfully (online)');
  //     } else {
  //       // Save offline using OfflineBillManager
  //       final offlineBillManager = OfflineBillManager();
  //       await offlineBillManager.initialize();
  //       await offlineBillManager.storeBillOffline(adminUid, billData);

  //       debugPrint('Bill saved offline successfully - will sync when online');
  //     }

  //     connectionMonitor.dispose();
  //   } catch (e) {
  //     debugPrint('Error saving bill: $e');

  //     // Fallback to offline storage if online save fails
  //     try {
  //       final now = DateTime.now();
  //       final dateString = DateFormat('MMM dd, yyyy').format(now);
  //       final monthDoc = DateFormat('yyyyMM').format(now);
  //       final dateDoc = DateFormat('yyyyMMdd').format(now);

  //       final itemsData = items.map((item) {
  //         return {
  //           'name': item['name'] ?? '',
  //           'price': double.tryParse(item['price'].toString()) ?? 0.0,
  //           'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
  //         };
  //       }).toList();

  //       final billData = {
  //         'id': receiptNo,
  //         'adminId': adminUid,
  //         'date': dateString,
  //         'items': itemsData,
  //         'receiptNo': receiptNo,
  //         'subTotal': subTotal,
  //         'monthDoc': monthDoc,
  //         'dateDoc': dateDoc,
  //         'createdAt': now.millisecondsSinceEpoch,
  //       };

  //       final offlineBillManager = OfflineBillManager();
  //       await offlineBillManager.initialize();
  //       await offlineBillManager.storeBillOffline(adminUid, billData);

  //       debugPrint('Bill saved offline as fallback after online failure');
  //     } catch (offlineError) {
  //       debugPrint('Failed to save bill offline: $offlineError');
  //       rethrow;
  //     }
  //   }
  // }

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

  static Future<void> printCustomerWiseReport({
    required BuildContext context,
    required BluetoothPrinter printer,
    required PaperSize paperSize,
    required String shopName,
    required String contact,
    required String address,
    required String customerName,
    required String customerPhone,
    required String customerGST,
    required DateTime fromDate,
    required DateTime toDate,
    required List<Map<String, dynamic>> bills,
    required double totalPaid,
    required double totalDue,
  }) async {
    try {
      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      bytes += generator.setGlobalCodeTable('CP1252');
      bool is58mm = paperSize == PaperSize.mm58;
      int totalCols = is58mm ? 32 : 48;
      String separator = '-' * totalCols;

      const smallFontCenter = PosStyles(align: PosAlign.center);
      const smallFontLeft = PosStyles(align: PosAlign.left);

      // ===== HEADER =====
      bytes += generator.text(shopName, styles: smallFontCenter);
      bytes += generator.text(address, styles: smallFontCenter);
      bytes += generator.text('Mob: $contact', styles: smallFontCenter);
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text(
        'CUSTOMER WISE REPORT',
        styles: smallFontCenter,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      // ===== DATE RANGE =====
      bytes += generator.text(
        'From: ${DateFormat('dd/MM/yyyy').format(fromDate)}',
        styles: smallFontLeft,
      );
      bytes += generator.text(
        'To  : ${DateFormat('dd/MM/yyyy').format(toDate)}',
        styles: smallFontLeft,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      // ===== CUSTOMER INFO =====
      bytes += generator.text(
        'Name:  $customerName',
        styles: smallFontLeft,
      );
      bytes += generator.text(
        'Phone: $customerPhone',
        styles: smallFontLeft,
      );
      if (customerGST.isNotEmpty) {
        bytes += generator.text(
          'GST:  $customerGST',
          styles: smallFontLeft,
        );
      }

      bytes += generator.text(separator, styles: smallFontLeft);

      int billCol = is58mm ? 4 : 10;
      int dateCol = is58mm ? 7 : 12;
      int payCol = is58mm ? 9 : 14;
      int amtCol = is58mm ? 11 : 10;
      bytes += generator.text(
        '${"No".padRight(billCol)}'
        '${"Date".padLeft(dateCol)}'
        '${"Mode".padLeft(payCol)}'
        '${"Amt".padLeft(amtCol)}',
        styles: smallFontLeft,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      // ===== BILLS =====
      for (final bill in bills) {
        bytes += generator.text(
          '${bill['billNo'].toString().padRight(billCol)}'
          '${bill['date'].padLeft(dateCol)}'
          '${bill['paymentType'].toString().toUpperCase().padLeft(payCol)}'
          '${bill['amount'].toStringAsFixed(0).padLeft(amtCol)}',
          styles: smallFontLeft,
        );
      }

      bytes += generator.text(separator, styles: smallFontLeft);

      // ===== TOTALS =====
      double grandTotal = totalPaid + totalDue;

      bytes += generator.text(
        'GRAND TOTAL'.padRight(totalCols - 10) + grandTotal.toStringAsFixed(0).padLeft(10),
        styles: const PosStyles(bold: true),
      );

      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        'Paid'.padRight(totalCols - 10) + totalPaid.toStringAsFixed(0).padLeft(10),
        styles: smallFontLeft,
      );

      bytes += generator.text(
        'Due'.padRight(totalCols - 10) + totalDue.toStringAsFixed(0).padLeft(10),
        styles: smallFontLeft,
      );

      // ===== FOOTER =====
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text('Thank you!', styles: smallFontCenter);
      bytes += generator.feed(4);

      // ===== PRINT =====
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer report printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Customer print error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
