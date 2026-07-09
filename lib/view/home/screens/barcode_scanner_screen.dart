import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/product_service.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/home/widgets/bill_cart_widget.dart';
import 'package:pos/view/home/widgets/show_save_order_bottom_sheet.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/data/providers/barcode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String)? onResult;
  const BarcodeScannerScreen({this.onResult, super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController controller;
  final GlobalKey scannerKey = GlobalKey(debugLabel: 'Scanner');

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  final TextEditingController _searchController = TextEditingController();

  // Shop details for navigation
  String shopName = '';
  String shopContact = '';
  String shopAddress = '';
  String adminUid = '';
  String phoneNo = '';
  String upiId = '';
  String logoUrl = '';

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      formats: [BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal,
    );
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      shopName = prefs.getString('shopName') ?? 'My Shop';
      shopContact = prefs.getString('contact') ?? '';
      shopAddress = prefs.getString('address') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
      phoneNo = prefs.getString('phoneNo') ?? '';
      upiId = prefs.getString('upiId') ?? '';
      logoUrl = prefs.getString('logoUrl') ?? '';
    });
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController gstController = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    _audioPlayer.dispose();
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    gstController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _saveDataAndNavigate(String? customerId) async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final selectedItemsDetails = printProvider.posts;
    final subtotal = printProvider.total;

    final userMap = {
      'userName': nameController.text,
      'phoneNumber': mobileController.text,
      'details': selectedItemsDetails
          .map((item) => {
                'name': item['name'],
                'price': item['price'],
                'quantity': item['quantity'],
              })
          .toList(),
      'totalAmount': subtotal,
      'customerId': customerId,
      'status': 'Pending',
      'timestamp': DateTime.now().toIso8601String(),
      'adminId': adminUid,
    };

    final box = await Hive.openBox('userBox');
    box.add(userMap);

    if (adminUid.isNotEmpty) {
      try {
        final orderService = OrderService();
        final formattedItems = selectedItemsDetails
            .map((item) => {
                  ...item,
                  'productId': item['productId'] ?? item['id'],
                  'total': (item['price'] as num) * (item['quantity'] as num),
                })
            .toList();

        await orderService.createOrder(
          adminId: adminUid,
          billNumber: 'POS-${DateTime.now().millisecondsSinceEpoch}',
          customerName: nameController.text,
          customerPhone: mobileController.text,
          customerId: customerId,
          items: formattedItems,
          orderType: 'Pickup',
          paymentMethod: 'Cash',
          paymentStatus: 'Due',
        );
      } catch (_) {
      }
    }

    printProvider.clearCart();
    nameController.clear();
    mobileController.clear();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UsersScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Immersive Camera Feed
          Positioned.fill(
            child: MobileScanner(
              key: scannerKey,
              controller: controller,
              onDetect: _onDetect,
            ),
          ),

          // 2. Premium Scanning Overlay
          _buildPremiumOverlay(),

          // 3. Top Action Bar (Glassmorphic style)
          _buildTopBar(),

          // 5. Integrated Bill Cart (Sliding from bottom)
          _buildSlidingCart(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: MyText(
                text: 'Barcode Scanner',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                textAlign: TextAlign.center,
              ),
            ),
            Consumer<BarcodeProvider>(
              builder: (context, barcodeProvider, child) {
                return IconButton(
                  icon: Icon(
                    barcodeProvider.isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: barcodeProvider.isFlashOn ? Colors.yellow : Colors.white,
                  ),
                  onPressed: () {
                    controller.toggleTorch();
                    barcodeProvider.toggleFlash();
                  },
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Background Dimming with Cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    height: 200,
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Animated Scanning Frame
          Center(
            child: SizedBox(
              height: 200,
              width: 280,
              child: Stack(
                children: [
                  _buildFrameCorner(Alignment.topLeft),
                  _buildFrameCorner(Alignment.topRight),
                  _buildFrameCorner(Alignment.bottomLeft),
                  _buildFrameCorner(Alignment.bottomRight),
                  const ScanningLine(height: 200),
                ],
              ),
            ),
          ),

          // Scanning Hint
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 + 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const MyText(
                  text: 'Align barcode within the frame',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
                ? const BorderSide(color: appbar1, width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
                ? const BorderSide(color: appbar1, width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
                ? const BorderSide(color: appbar1, width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
                ? const BorderSide(color: appbar1, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft ? const Radius.circular(12) : Radius.zero,
            topRight: alignment == Alignment.topRight ? const Radius.circular(12) : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft ? const Radius.circular(12) : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight ? const Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingCart() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: BillCart(
        onCartCleared: () {},
        onCartUpdated: (_, __) {},
        orderBottomSheet: () {
          final printProvider = Provider.of<PrintProvider>(context, listen: false);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SaveOrderBottomSheet(
              formKey: _formKey,
              nameController: nameController,
              mobileController: mobileController,
              gstController: gstController,
              addressController: addressController,
              itemCount: printProvider.posts.length,
              totalAmount: printProvider.total,
              primaryColor: appbar1,
              onCancel: () => Navigator.pop(context),
              onSave: (customerId) {
                if (_formKey.currentState!.validate()) {
                  _saveDataAndNavigate(customerId);
                  Navigator.pop(context);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedCode == code && _lastScanTime != null && now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    final barcodeProvider = Provider.of<BarcodeProvider>(context, listen: false);
    if (barcodeProvider.isProcessing) return;
    _processBarcode(code);
  }

  Future<void> _processBarcode(String code) async {
    final barcodeProvider = Provider.of<BarcodeProvider>(context, listen: false);

    barcodeProvider.setProcessing(true);
    _lastScannedCode = code;
    _lastScanTime = DateTime.now();

    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));

      // Visual feedback Haptic
      HapticFeedback.heavyImpact();

      if (widget.onResult != null) {
        widget.onResult!(code);
        if (mounted) Navigator.pop(context);
        return;
      }

      final productService = ProductService();
      final products = await productService.getProducts(barcode: code);

      if (products.isNotEmpty) {
        final product = products.first;
        if (mounted) {
          final printProvider = Provider.of<PrintProvider>(context, listen: false);
          printProvider.addToCart(product);
          SnackBarUtils.showSuccess(context, 'Added: ${product.name}');

          // Briefly expand cart to show item added
          if (!printProvider.isCartExpanded) {
            printProvider.setCartExpanded(true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) printProvider.setCartExpanded(false);
            });
          }
        }
      } else {
        if (mounted) {
          SnackBarUtils.showWarning(context, 'Product not found: $code');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        barcodeProvider.setProcessing(false);
      }
    }
  }
}

class ScanningLine extends StatefulWidget {
  final double height;
  const ScanningLine({required this.height, super.key});

  @override
  State<ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _controller.value * widget.height,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  appbar1.withOpacity(0),
                  appbar1,
                  appbar1.withOpacity(0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: appbar1.withOpacity(0.8),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
