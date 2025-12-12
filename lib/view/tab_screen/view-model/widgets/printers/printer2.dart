// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';
// // import 'package:image/image.dart' as img;
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
// import 'package:intl/intl.dart';
// import 'package:pos/view/home/calculator_screen.dart';

// class Printer2 extends StatefulWidget {
//   final Map<int, FoodItem> cart;
//   Printer2({
//     Key? key,
//     required this.cart,
//   }) : super(key: key);

//   @override
//   State<Printer2> createState() => _PrinterState();
// }

// class _PrinterState extends State<Printer2> {
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
//   // _currentUsbStatus is only supports on Android
//   // ignore: unused_field
//   USBStatus _currentUsbStatus = USBStatus.none;
//   List<int>? pendingTask;
//   String _ipAddress = '';
//   String _port = '9100';
//   final _ipController = TextEditingController();
//   final _portController = TextEditingController();
//   BluetoothPrinter? selectedPrinter;

//   @override
//   void initState() {
//     if (Platform.isWindows) defaultPrinterType = PrinterType.usb;
//     super.initState();
//     _portController.text = _port;
//     _scan();

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
//     //  PrinterManager.instance.stateUSB is only supports on Android
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

//   @override
//   void dispose() {
//     _subscription?.cancel();
//     _subscriptionBtStatus?.cancel();
//     _subscriptionUsbStatus?.cancel();
//     _portController.dispose();
//     _ipController.dispose();
//     super.dispose();
//   }

//   // method to scan devices according PrinterType
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

//   Future _printReceiveTest() async {
//     // Get the current date
//     DateTime currentDate = DateTime.now();
//     // Format the date as a string in the "yyyy-MM-dd" format
//     String formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);

//     List<int> bytes = [];

//     // Xprinter XP-N160I
//     final profile = await CapabilityProfile.load(name: 'XP-N160I');
//     // PaperSize.mm80 or PaperSize.mm58
//     final generator = Generator(PaperSize.mm80, profile);
//     bytes += generator.setGlobalCodeTable('CP1252');

//     // Implementation of the image printing function

//     // final ByteData data = await rootBundle.load('assets/parking.webp');
//     // final Uint8List imgData = data.buffer.asUint8List();
//     // final image = img.decodeImage(imgData);
//     // const int newWidth = 200;
//     // const int newHeight = 200;
//     // final resizedImage =
//     //     img.copyResize(image!, width: newWidth, height: newHeight);
//     // bytes += generator.imageRaster(resizedImage);

//     bytes += generator.text('SHOP NAME',
//         styles: const PosStyles(
//             align: PosAlign.center, bold: true, fontType: PosFontType.fontA));
//     bytes += generator.text('Address: Gurugram, Haryana, $formattedDate',
//         styles: const PosStyles(align: PosAlign.center));
//     bytes += generator.text('Tel: +91 6123456789',
//         styles: const PosStyles(align: PosAlign.center));
//     bytes += generator.text('*************************************',
//         styles: const PosStyles(align: PosAlign.center));
//     bytes += generator.text('RECEIPT',
//         styles: const PosStyles(align: PosAlign.center));
//     bytes += generator.text('*************************************',
//         styles: const PosStyles(align: PosAlign.center));

//     widget.cart.forEach((key, foodItem) {
//       bytes += generator.text('Name: ${foodItem.name}',
//           styles: const PosStyles(align: PosAlign.left));
//       bytes += generator.text('Quantity: ${foodItem.quantity}',
//           styles: const PosStyles(align: PosAlign.left));
//       bytes += generator.text('Price: ${foodItem.price * foodItem.quantity}',
//           styles: const PosStyles(align: PosAlign.left));
//     });

//     bytes += generator.text('*************************************',
//         styles: const PosStyles(align: PosAlign.center, bold: true));

//     bytes += generator.text('Total:                                  ',
//         styles: const PosStyles(
//             align: PosAlign.center, bold: true, width: PosTextSize.size5));
//     _printEscPos(bytes, generator);
//   }

//   /// print ticket
//   void _printEscPos(List<int> bytes, Generator generator) async {
//     if (selectedPrinter == null) return;
//     var bluetoothPrinter = selectedPrinter!;

//     switch (bluetoothPrinter.typePrinter) {
//       case PrinterType.usb:
//         bytes += generator.feed(2);
//         bytes += generator.cut();
//         await printerManager.connect(
//             type: bluetoothPrinter.typePrinter,
//             model: UsbPrinterInput(
//                 name: bluetoothPrinter.deviceName,
//                 productId: bluetoothPrinter.productId,
//                 vendorId: bluetoothPrinter.vendorId));
//         pendingTask = null;
//         break;
//       case PrinterType.bluetooth:
//         bytes += generator.cut();
//         await printerManager.connect(
//             type: bluetoothPrinter.typePrinter,
//             model: BluetoothPrinterInput(
//                 name: bluetoothPrinter.deviceName,
//                 address: bluetoothPrinter.address!,
//                 isBle: bluetoothPrinter.isBle ?? false,
//                 autoConnect: _reconnect));
//         pendingTask = null;
//         if (Platform.isAndroid) pendingTask = bytes;
//         break;
//       case PrinterType.network:
//         bytes += generator.feed(2);
//         bytes += generator.cut();
//         await printerManager.connect(
//             type: bluetoothPrinter.typePrinter,
//             model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!));
//         break;
//       default:
//     }
//     if (bluetoothPrinter.typePrinter == PrinterType.bluetooth &&
//         Platform.isAndroid) {
//       if (_currentStatus == BTStatus.connected) {
//         printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
//         pendingTask = null;
//       }
//     } else {
//       printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
//     }
//   }

//   // conectar dispositivo
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
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Print Receipt'),
//       ),
//       body: Center(
//         child: Container(
//           height: double.infinity,
//           constraints: const BoxConstraints(maxWidth: 400),
//           child: SingleChildScrollView(
//             padding: EdgeInsets.zero,
//             child: Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             foregroundColor: Colors.black,
//                             backgroundColor:
//                                 const Color.fromARGB(255, 125, 237, 155),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(30),
//                             ),
//                           ),
//                           onPressed: selectedPrinter == null || _isConnected
//                               ? null
//                               : () {
//                                   _connectDevice();
//                                 },
//                           child: const Text("Connect",
//                               textAlign: TextAlign.center),
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             foregroundColor: Colors.black,
//                             backgroundColor:
//                                 const Color.fromARGB(255, 125, 237, 155),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(30),
//                             ),
//                           ),
//                           onPressed: selectedPrinter == null || !_isConnected
//                               ? null
//                               : () {
//                                   if (selectedPrinter != null)
//                                     printerManager.disconnect(
//                                         type: selectedPrinter!.typePrinter);
//                                   setState(() {
//                                     _isConnected = false;
//                                   });
//                                 },
//                           child: const Text("Disconnect",
//                               textAlign: TextAlign.center),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 DropdownButtonFormField<PrinterType>(
//                   value: defaultPrinterType,
//                   decoration: const InputDecoration(
//                     prefixIcon: Icon(
//                       Icons.print,
//                       size: 24,
//                     ),
//                     labelText: "Type Printer Device",
//                     labelStyle: TextStyle(fontSize: 18.0),
//                     focusedBorder: InputBorder.none,
//                     enabledBorder: InputBorder.none,
//                   ),
//                   items: <DropdownMenuItem<PrinterType>>[
//                     if (Platform.isAndroid || Platform.isIOS)
//                       const DropdownMenuItem(
//                         value: PrinterType.bluetooth,
//                         child: Text("bluetooth"),
//                       ),
//                     if (Platform.isAndroid || Platform.isWindows)
//                       const DropdownMenuItem(
//                         value: PrinterType.usb,
//                         child: Text("usb"),
//                       ),
//                     const DropdownMenuItem(
//                       value: PrinterType.network,
//                       child: Text("Wifi"),
//                     ),
//                   ],
//                   onChanged: (PrinterType? value) {
//                     setState(() {
//                       if (value != null) {
//                         setState(() {
//                           defaultPrinterType = value;
//                           selectedPrinter = null;
//                           _isBle = false;
//                           _isConnected = false;
//                           _scan();
//                         });
//                       }
//                     });
//                   },
//                 ),
//                 Visibility(
//                   visible: defaultPrinterType == PrinterType.bluetooth &&
//                       Platform.isAndroid,
//                   child: SwitchListTile.adaptive(
//                     contentPadding:
//                         const EdgeInsets.only(bottom: 20.0, left: 20),
//                     title: const Text(
//                       "reconnect",
//                       textAlign: TextAlign.start,
//                       style: TextStyle(fontSize: 19.0),
//                     ),
//                     value: _reconnect,
//                     onChanged: (bool? value) {
//                       setState(() {
//                         _reconnect = value ?? false;
//                       });
//                     },
//                   ),
//                 ),
//                 Column(
//                     children: devices
//                         .map(
//                           (device) => ListTile(
//                             title: Text('${device.deviceName}'),
//                             subtitle: Platform.isAndroid &&
//                                     defaultPrinterType == PrinterType.usb
//                                 ? null
//                                 : Visibility(
//                                     visible: !Platform.isWindows,
//                                     child: Text("${device.address}")),
//                             onTap: () {
//                               // do something
//                               selectDevice(device);
//                             },
//                             leading: selectedPrinter != null &&
//                                     ((device.typePrinter == PrinterType.usb &&
//                                                 Platform.isWindows
//                                             ? device.deviceName ==
//                                                 selectedPrinter!.deviceName
//                                             : device.vendorId != null &&
//                                                 selectedPrinter!.vendorId ==
//                                                     device.vendorId) ||
//                                         (device.address != null &&
//                                             selectedPrinter!.address ==
//                                                 device.address))
//                                 ? const Icon(
//                                     Icons.check,
//                                     color: Colors.green,
//                                   )
//                                 : null,
//                             trailing: OutlinedButton(
//                               onPressed: selectedPrinter == null ||
//                                       device.deviceName !=
//                                           selectedPrinter?.deviceName
//                                   ? null
//                                   : () async {
//                                       _printReceiveTest();
//                                       Navigator.pop(context);
//                                     },
//                               child: const Padding(
//                                 padding: EdgeInsets.symmetric(
//                                     vertical: 2, horizontal: 20),
//                                 child: Text("Print Receipt",
//                                     textAlign: TextAlign.center),
//                               ),
//                             ),
//                           ),
//                         )
//                         .toList()),
//                 Visibility(
//                   visible: defaultPrinterType == PrinterType.network &&
//                       Platform.isWindows,
//                   child: Padding(
//                     padding: const EdgeInsets.only(top: 10.0),
//                     child: TextFormField(
//                       controller: _ipController,
//                       keyboardType:
//                           const TextInputType.numberWithOptions(signed: true),
//                       decoration: const InputDecoration(
//                         label: Text("Ip Address"),
//                         prefixIcon: Icon(Icons.wifi, size: 24),
//                       ),
//                       onChanged: setIpAddress,
//                     ),
//                   ),
//                 ),
//                 Visibility(
//                   visible: defaultPrinterType == PrinterType.network &&
//                       Platform.isWindows,
//                   child: Padding(
//                     padding: const EdgeInsets.only(top: 10.0),
//                     child: TextFormField(
//                       controller: _portController,
//                       keyboardType:
//                           const TextInputType.numberWithOptions(signed: true),
//                       decoration: const InputDecoration(
//                         label: Text("Port"),
//                         prefixIcon: Icon(Icons.numbers_outlined, size: 24),
//                       ),
//                       onChanged: setPort,
//                     ),
//                   ),
//                 ),
//                 Visibility(
//                   visible: defaultPrinterType == PrinterType.network &&
//                       Platform.isWindows,
//                   child: Padding(
//                     padding: const EdgeInsets.only(top: 10.0),
//                     child: OutlinedButton(
//                       onPressed: () async {
//                         if (_ipController.text.isNotEmpty)
//                           setIpAddress(_ipController.text);
//                         _printReceiveTest();
//                       },
//                       child: const Padding(
//                         padding:
//                             EdgeInsets.symmetric(vertical: 4, horizontal: 50),
//                         child: Text("Print test ticket",
//                             textAlign: TextAlign.center),
//                       ),
//                     ),
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class BluetoothPrinter {
//   int? id;
//   String? deviceName;
//   String? address;
//   String? port;
//   String? vendorId;
//   String? productId;
//   bool? isBle;

//   PrinterType typePrinter;
//   bool? state;

//   BluetoothPrinter(
//       {this.deviceName,
//       this.address,
//       this.port,
//       this.state,
//       this.vendorId,
//       this.productId,
//       this.typePrinter = PrinterType.bluetooth,
//       this.isBle = false});
// }
