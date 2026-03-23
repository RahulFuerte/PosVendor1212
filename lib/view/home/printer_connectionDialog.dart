// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';

class PrinterConnectionDialog extends StatefulWidget {
  const PrinterConnectionDialog({Key? key}) : super(key: key);

  @override
  State<PrinterConnectionDialog> createState() =>
      _PrinterConnectionDialogState();
}

class _PrinterConnectionDialogState extends State<PrinterConnectionDialog> {
  var defaultPrinterType = PrinterType.bluetooth;
  var _isBle = false;
  final _reconnect = false;
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  BTStatus _currentStatus = BTStatus.none;
  BluetoothPrinter? selectedPrinter;
  PaperSize selectedPaperSize = PaperSize.mm58;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) defaultPrinterType = PrinterType.usb;

    // Load saved printer settings from provider
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    if (printProvider.selectedPrinter != null) {
      selectedPrinter = printProvider.selectedPrinter;
      selectedPaperSize = printProvider.selectedPaperSize;
    }

    _subscriptionBtStatus = printerManager.stateBluetooth.listen((status) {
      _currentStatus = status;
      if (status == BTStatus.connected && mounted) {
        setState(() {
          _isConnecting = false;
        });
        final printProvider =
            Provider.of<PrintProvider>(context, listen: false);
        printProvider.setConnected(true);
      }
      if (status == BTStatus.none && mounted) {
        setState(() {
          _isConnecting = false;
        });
        final printProvider =
            Provider.of<PrintProvider>(context, listen: false);
        printProvider.setConnected(false);
      }
    });

    _scan();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscriptionBtStatus?.cancel();
    super.dispose();
  }

  void _scan() {
    devices.clear();
    _subscription = printerManager
        .discovery(type: defaultPrinterType, isBle: _isBle)
        .listen((device) {
      devices.add(BluetoothPrinter(
        deviceName: device.name,
        address: device.address,
        isBle: _isBle,
        vendorId: device.vendorId,
        productId: device.productId,
        typePrinter: defaultPrinterType,
      ));
      if (mounted) {
        setState(() {});
      }
    });
  }

  void selectDevice(BluetoothPrinter device) {
    setState(() {
      selectedPrinter = device;
    });
  }

  Future<void> _connectDevice() async {
    if (selectedPrinter == null) return;

    setState(() {
      _isConnecting = true;
    });

    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    try {
      switch (selectedPrinter!.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
              type: selectedPrinter!.typePrinter,
              model: UsbPrinterInput(
                  name: selectedPrinter!.deviceName,
                  productId: selectedPrinter!.productId,
                  vendorId: selectedPrinter!.vendorId));
          printProvider.setConnected(true);
          break;
        case PrinterType.bluetooth:
          await printerManager.connect(
              type: selectedPrinter!.typePrinter,
              model: BluetoothPrinterInput(
                  name: selectedPrinter!.deviceName,
                  address: selectedPrinter!.address!,
                  isBle: selectedPrinter!.isBle ?? false,
                  autoConnect: _reconnect));
          break;
        case PrinterType.network:
          await printerManager.connect(
              type: selectedPrinter!.typePrinter,
              model: TcpPrinterInput(ipAddress: selectedPrinter!.address!));
          printProvider.setConnected(true);
          break;
        default:
      }

      printProvider.setSelectedPrinter(selectedPrinter);
      printProvider.setPaperSize(selectedPaperSize);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: MyText(text: 'Printer connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: 'Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const MyText(
                  text: 'Connect Printer',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            DropdownButtonFormField<PaperSize>(
              value: selectedPaperSize,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.receipt_long),
                labelText: "Paper Size",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: PaperSize.mm58, child: MyText(text: "58mm")),
                DropdownMenuItem(value: PaperSize.mm80, child: MyText(text: "80mm")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedPaperSize = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrinterType>(
              value: defaultPrinterType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.print),
                labelText: "Printer Type",
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<PrinterType>>[
                if (Platform.isAndroid || Platform.isIOS)
                  const DropdownMenuItem(
                    value: PrinterType.bluetooth,
                    child: MyText(text: "Bluetooth"),
                  ),
                if (Platform.isAndroid || Platform.isWindows)
                  const DropdownMenuItem(
                    value: PrinterType.usb,
                    child: MyText(text: "USB"),
                  ),
                const DropdownMenuItem(
                  value: PrinterType.network,
                  child: MyText(text: "WiFi"),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    defaultPrinterType = value;
                    selectedPrinter = null;
                    _isBle = false;
                    _scan();
                  });
                }
              },
            ),
            if (defaultPrinterType == PrinterType.bluetooth &&
                Platform.isAndroid)
              // SwitchListTile(
              //   title: const Text("Auto Reconnect"),
              //   value: _reconnect,
              //   onChanged: (value) {
              //     setState(() {
              //       _reconnect = value;
              //     });
              //   },
              // ),
              const SizedBox(height: 16),
            const MyText(
              text: 'Available Devices:',
              fontWeight: FontWeight.bold,
            ),
            const Divider(),
            Expanded(
              child: devices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isSelected =
                            selectedPrinter?.deviceName == device.deviceName;
                        return ListTile(
                          leading: Icon(
                            Icons.print,
                            color: isSelected ? Colors.green : null,
                          ),
                          title: MyText(text: device.deviceName ?? 'Unknown'),
                          subtitle: device.address != null
                              ? MyText(text: device.address!)
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                          selected: isSelected,
                          onTap: () => selectDevice(device),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link),
                label:
                    MyText(text: _isConnecting ? 'Connecting...' : 'Connect Printer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: selectedPrinter == null || _isConnecting
                    ? null
                    : _connectDevice,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
