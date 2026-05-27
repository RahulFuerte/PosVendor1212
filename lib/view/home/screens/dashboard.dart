import 'package:flutter/material.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/report_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/screens/receipt_data_screen.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/view/home/screens/order_management_screen.dart';
import 'package:pos/view/home/widgets/order_kot_widgets.dart';
import 'package:pos/core/utils/pdf_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';


class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String name = '';
  String phoneNo = '';
  String adminUid = '';
  String businessCategory = 'Food';

  List<Map<String, dynamic>> orders = [];
  bool isLoading = false;
  int totalBills = 0;
  int totalSales = 0;
  int totalExpenses = 0;
  int netProfit = 0;
  Map<String, dynamic> orderDistribution = {};
  List<dynamic> salesOverview = [];
  bool _isShopOpen = false;
  bool _isToggling = false;

  late String monthKey;
  late String dateKey;

  DateTime selectedDate = DateTime.now();
  String selectedOrderType = 'all';

  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final ReportService _reportService = ReportService();
  final OrderService _orderService = OrderService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  TutorialCoachMark? _tourMark;

  void _checkTour() {
    final tourProvider = context.read<TourProvider>();
    if (tourProvider.isTourActive && tourProvider.currentStep == 14) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showTour();
      });
    }
  }

  void _showTour() {
    final tourProvider = context.read<TourProvider>();
    final targets = [
      TargetFocus(
        identify: "dash_drawer",
        keyTarget: TourKeys.drawerIconKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 14,
                title: AppLocale.tourTitle11.getString(context),
                description: AppLocale.tourDesc11.getString(context),
                onNext: () => controller.next(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "dash_sales",
        keyTarget: TourKeys.dashSalesCardKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 15,
                title: AppLocale.tourTitle12.getString(context),
                description: AppLocale.tourDesc12.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "dash_recent_orders",
        keyTarget: TourKeys.dashRecentOrdersKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 16,
                title: AppLocale.tourTitle13.getString(context),
                description: AppLocale.tourDesc13.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
    ];

    final validTargets = targets.where((t) {
      final k = t.keyTarget;
      return k == null || k.currentContext != null;
    }).toList();
    if (validTargets.isEmpty) {
      if (tourProvider.isTourActive) {
        Navigator.of(context).pop();
        tourProvider.setStep(17);
      }
      return;
    }

    _tourMark = TutorialCoachMark(
      targets: validTargets,
      hideSkip: true,
      colorShadow: Colors.black.withOpacity(0.85),
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        if (tourProvider.isTourActive) {
          Navigator.of(context).pop();
          tourProvider.setStep(17);
        }
      },
      onSkip: () {
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
  }

  @override
  void dispose() {
    _tourMark?.finish();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    monthKey = DateFormat('yyyyMM').format(now);
    dateKey = DateFormat('yyyyMMdd').format(now);
    _loadSessionData().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkTour();
      });
    });
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
      name = prefs.getString('shopName') ?? prefs.getString('businessName') ?? 'Shop Name';
      businessCategory = prefs.getString('businessCategory') ?? 'Food';
    });
    _fetchShopStatus();
    fetchOrders();
  }

  Future<void> _fetchShopStatus() async {
    // 1. Load from local cache first for instant feedback
    final prefs = await SharedPreferences.getInstance();
    final cachedStatus = prefs.getBool('isShopOpen');
    setState(() => _isShopOpen = cachedStatus ?? false);

    // 2. Fetch from server to sync
    try {
      final user = await UserService().getProfile();
      if (user.isShopOpen != null) {
        setState(() => _isShopOpen = user.isShopOpen!);
        await prefs.setBool('isShopOpen', user.isShopOpen!);
      }
    } catch (e) {
      // Error fetching shop status
    }
  }

  Future<void> _toggleShopStatus(bool val) async {
    setState(() => _isToggling = true);
    try {
      await UserService().updateProfile({'isShopOpen': val});
      setState(() => _isShopOpen = val);
      if (mounted) {
        if (val) {
          SnackBarUtils.showSuccess(context, 'Shop is now Open');
        } else {
          SnackBarUtils.showError(context, 'Shop is now Closed');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to update shop status: $e');
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> fetchOrders() async {
    try {
      setState(() => isLoading = true);

      // Online-Only Fetch Logic
      final apiResponse = await _reportService.getDashboardReport(
        date: selectedDate,
        orderType: selectedOrderType == 'all' ? null : selectedOrderType,
      );

      if (apiResponse['success'] == true) {
        final data = apiResponse; // Fields are at top level
        final List<dynamic> apiOrders = data['orders'] ?? [];

        setState(() {
          orders = apiOrders.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          totalBills = (data['totalBills'] ?? apiOrders.length).toInt();
          totalSales = ((data['totalSales'] ?? 0) as num).toInt();
          totalExpenses = ((data['totalExpense'] ?? 0) as num).toInt();
          netProfit = ((data['netProfit'] ?? 0) as num).toInt();
          orderDistribution = Map<String, dynamic>.from(data['orderDistribution'] ?? {});
          salesOverview = List<dynamic>.from(data['salesOverview'] ?? []);
        });
      } else {
        setState(() {
          orders = [];
          totalBills = 0;
          totalSales = 0;
          totalExpenses = 0;
          netProfit = 0;
          orderDistribution = {};
          salesOverview = [];
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to fetch dashboard data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  DateTime _parseToLocalDate(dynamic dateData) {
    if (dateData == null) return DateTime.now();
    if (dateData is Map && dateData.containsKey('\$date')) {
      return DateTime.parse(dateData['\$date'].toString()).toLocal();
    }
    if (dateData is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateData).toLocal();
    }
    try {
      return DateTime.parse(dateData.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _orderTypeText(String type) {
    String t = type.toLowerCase();
    if (t == 'dinein') {
      return businessCategory == 'Food' ? 'DineIn' : '';
    }
    if (t == 'pickup') {
      return businessCategory == 'Food' ? 'PickUp' : '';
    }
    if (t == 'delivery') return 'Delivery';
    return type;
  }

  Color _orderTypeColor(String type) {
    String t = type.toLowerCase();
    if (t == 'dinein') return Colors.teal;
    if (t == 'pickup') return Colors.orange;
    if (t == 'delivery') return Colors.red;
    return Colors.grey;
  }

  Future<void> _handlePrint({
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required String customerName,
    required String customerPhone,
    required String customerGst,
    required String customerNote,
    required String customerAddress,
    required double discountAmount,
    required double discountPercent,
    required String receiptNo,
    required String orderType,
    required String paymentType,
  }) async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
      showDialog(
        context: context,
        builder: (context) => const PrinterConnectionDialog(),
      );
      SnackBarUtils.showWarning(context, 'Please connect a printer first');
      return;
    }

    if (items.isEmpty) {
      SnackBarUtils.showWarning(context, 'No items to print');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate sequential receipt number (returns 8-digit padded string like "00000001")
      String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(phoneNo);
      final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
      String paymentType = orderTypeProvider.paymentType.toString().split('.').last;
      String orderType = orderTypeProvider.orderType.toString().split('.').last;

      // Fetch shop data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String shopName = prefs.getString('shopName') ?? 'Shop Name';
      String contact = prefs.getString('contact') ?? 'Contact';
      String address = prefs.getString('address') ?? 'Address';
      String logoUrl = prefs.getString('logoUrl') ?? '';
      String upiId = prefs.getString('upiId') ?? "";

      await DirectPrintHelper().printReceipt(
        adminUid: phoneNo,
        context: context,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: items,
        subTotal: subTotal,
        shopName: shopName,
        contact: contact,
        address: address,
        logoUrl: logoUrl,
        upiId: upiId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerGst: customerGst,
        customerNote: customerNote,
        customerAddress: customerAddress,
        orderType: orderType,
        paymentType: paymentType,
        discountAmount: discountAmount,
        discountPercent: discountPercent,
        receiptNo: receiptNo,
        taxEnabled: printProvider.taxEnabled,
        cgstPercent: printProvider.cgstPercent,
        sgstPercent: printProvider.sgstPercent,
        saveBill: false,
      );

      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Printing failed: $e');
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Ensure we close the correct loader dialog
      }
    }
  }

  Future<void> _handleWhatsapp({
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required double finalAmount,
    required String customerName,
    required String customerPhone,
    required String receiptNo,
    required String orderType,
    required String paymentType,
    required DateTime dateTime,
  }) async {
    try {
      final String cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');

      final prefs = await SharedPreferences.getInstance();
      final String shopName = prefs.getString('shopName') ?? 'Our Shop';

      // Construct a professional message
      String message = "🏪 *${shopName.toUpperCase()}* 🏪\n"
          "✨ *Bill Summary: #$receiptNo* ✨\n\n"
          "👤 *Customer:* ${customerName.isEmpty ? 'Guest' : customerName}\n"
          "📅 *Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(dateTime)}\n"
          "🍴 *Order Type:* $orderType\n"
          "💳 *Payment:* $paymentType\n\n"
          "*Items:*\n";

      for (var item in items) {
        message += "• ${item['name']} x ${item['quantity']} = ₹${item['price'] * item['quantity']}\n";
      }

      message += "\n💰 *Total Amount: ₹$finalAmount*\n\n"
          "Thank you for visiting *$shopName*! 🙏";

      if (cleanPhone.isNotEmpty) {
        // Standardize phone number (assuming 10 digits means India +91)
        String formattedPhone = cleanPhone;
        if (formattedPhone.length == 10) {
          formattedPhone = "91$formattedPhone";
        }

        final Uri whatsappUri = Uri.parse(
          "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}",
        );

        if (await canLaunchUrl(whatsappUri)) {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) SnackBarUtils.showError(context, "Could not launch WhatsApp");
        }
      } else {
        // No phone number, just open WhatsApp or share via PDF as fallback
        final Uri generalWhatsappUri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(generalWhatsappUri)) {
          await launchUrl(generalWhatsappUri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to original PDF sharing if WhatsApp URI fails
          final prefs = await SharedPreferences.getInstance();
          final printProvider = Provider.of<PrintProvider>(context, listen: false);
          await PdfHelper.generateAndShareBillPdf(
            shopName: prefs.getString('shopName') ?? 'Shop Name',
            address: prefs.getString('address') ?? 'Address',
            contact: prefs.getString('contact') ?? 'Contact',
            receiptNo: receiptNo,
            dateTime: dateTime,
            items: items,
            subTotal: subTotal,
            finalTotal: finalAmount,
            paymentType: paymentType,
            orderType: orderType,
            customerName: customerName,
            customerPhone: customerPhone,
            taxEnabled: printProvider.taxEnabled,
            cgstPercent: printProvider.cgstPercent,
            sgstPercent: printProvider.sgstPercent,
            discountAmount: subTotal - finalAmount,
          );
        }
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, "Error opening WhatsApp: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey.shade100,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pop(context);
          },
          backgroundColor: appbar1,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(Icons.add_shopping_cart),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              key: TourKeys.drawerIconKey,
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: name,
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
              MyText(
                text: phoneNo,
                fontSize: 14,
                color: Colors.grey,
              ),
            ],
          ),
          actions: [
            _buildStatusToggle(),
            const SizedBox(width: 8),
          ],
        ),
        drawer: MyDrawer(
          phoneNo: phoneNo,
          adminPhoneNo: phoneNo,
        ),
        body: isLoading
            ? const _DashboardSkeleton()
            : RefreshIndicator(
                onRefresh: () async {
                  await fetchOrders();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _InfoCard(
                            key: TourKeys.dashSalesCardKey,
                            title: AppLocale.sales.getString(context),
                            value: PriceUtils.formatPrice(totalSales),
                            icon: Icons.point_of_sale,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 10),
                          _InfoCard(
                            title: AppLocale.netProfit.getString(context),
                            value: PriceUtils.formatPrice(netProfit),
                            icon: Icons.account_balance_wallet,
                            color: Colors.indigo,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          _InfoCard(
                            title: AppLocale.totalBills.getString(context),
                            value: numberFormat.format(totalBills),
                            icon: Icons.receipt,
                            color: appbar1,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _InfoCard(
                            title: AppLocale.totalExpenses.getString(context),
                            value: PriceUtils.formatPrice(totalExpenses),
                            icon: Icons.trending_down,
                            color: Colors.red.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              text: AppLocale.filterOrders.getString(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                /// 📅 DATE FILTER
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime(2023),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setState(() => selectedDate = picked);
                                        fetchOrders();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: appbar1.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: appbar1.withOpacity(0.25)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_month, color: appbar1),
                                          const SizedBox(width: 10),
                                          MyText(
                                            text: DateFormat('dd MMM yyyy').format(selectedDate),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                /// 🍽 ORDER TYPE FILTER
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedOrderType,
                                    isDense: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: appbar1.withOpacity(0.08),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: appbar1.withOpacity(0.25)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: appbar1.withOpacity(0.25)),
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: MyText(text: AppLocale.allOrders.getString(context)),
                                      ),
                                      if (businessCategory == 'Food') ...[
                                        DropdownMenuItem(
                                          value: 'DineIn',
                                          child: MyText(text: '🍽 ' + AppLocale.dineIn.getString(context)),
                                        ),
                                        DropdownMenuItem(
                                          value: 'PickUp',
                                          child: MyText(text: '🛍 ' + AppLocale.pickUp.getString(context)),
                                        ),
                                      ],
                                      DropdownMenuItem(
                                        value: 'Delivery',
                                        child: MyText(text: '🚚 ' + AppLocale.delivery.getString(context)),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => selectedOrderType = value!);
                                      fetchOrders();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (salesOverview.isNotEmpty) _SalesOverviewChart(data: salesOverview),
                      const SizedBox(height: 15),
                      if (orderDistribution.isNotEmpty && businessCategory == 'Food')
                        _OrderDistributionChart(data: orderDistribution, businessCategory: businessCategory),
                      if (businessCategory == 'Food') const SizedBox(height: 15),
                       Padding(
                        key: TourKeys.dashRecentOrdersKey,
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MyText(
                              text: AppLocale.recentOrders.getString(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderManagementScreen(),
                                  ),
                                );
                              },
                              child: MyText(
                                text: AppLocale.viewAll.getString(context),
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      orders.isEmpty
                          ? Center(child: MyText(text: AppLocale.noOrdersFound.getString(context)))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                            itemCount: orders.length > 10 ? 10 : orders.length,
                                  itemBuilder: (context, index) {
                                    final data = orders[index];
                                    final dateData = data['orderDate'] ?? data['created_at'];
                                    DateTime dt = _parseToLocalDate(dateData);
                                    String timeStr = DateFormat('dd/MM/yy hh:mm a').format(dt);

                                    // Extract guest/customer name
                                    String customerName = data['customerName'] ?? data['customer_name'] ?? "";
                                    if (customerName.isEmpty && data['unknownCustomerId'] != null) {
                                      customerName = data['unknownCustomerId']['name'] ?? AppLocale.guestUser.getString(context);
                                    }
                                    if (customerName.isEmpty) customerName = AppLocale.walkIn.getString(context);

                                    return OrderTile(
                                      bill: data['billNumber'] ?? data['id'] ?? '0',
                                      amount: ((data['finalAmount'] ?? data['final_total'] ?? data['sub_total'] ?? 0)
                                              as num)
                                          .toInt(),
                                      time: timeStr,
                                      customerName: customerName,
                                      paymentStatus: data['paymentStatus'] ?? "Due",
                                      status: data['status'] ?? "Pending",
                                      typeText: _orderTypeText(data['orderType'] ?? data['order_type'] ?? 'all'),
                                      typeColor: _orderTypeColor(data['orderType'] ?? data['order_type'] ?? 'all'),
                                      onTap: () async {
                                        final prefs = await SharedPreferences.getInstance();
                                        final items = (data['items'] as List<dynamic>? ?? [])
                                            .map((e) => Map<String, dynamic>.from(e as Map))
                                            .toList();
                                        // ignore: use_build_context_synchronously
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReceiptPreviewOnlyWidget(
                                              orderId: (data['_id'] ?? data['id'] ?? '').toString(),
                                              initialPaymentStatus: data['paymentStatus'] ?? 'Due',
                                              isUnknownCustomer: data['unknownCustomerId'] != null,
                                              userPhoneNumber: phoneNo,
                                              shopName: prefs.getString('shopName') ?? 'Shop Name',
                                              address: prefs.getString('address') ?? 'Address',
                                              contact: prefs.getString('contact') ?? 'Contact',
                                              receiptNo: (data['billNumber'] ?? '').toString(),
                                              dateTime: _parseToLocalDate(data['orderDate'] ?? data['created_at']),
                                              items: items,
                                              subTotal: ((data['totalAmount'] ??
                                                      data['subTotal'] ??
                                                      data['sub_total'] ??
                                                      0) as num)
                                                  .toDouble(),
                                              finalTotal: ((data['finalAmount'] ??
                                                      data['final_total'] ??
                                                      data['sub_total'] ??
                                                      0) as num)
                                                  .toDouble(),
                                              discountAmount:
                                                  ((data['discount'] ?? data['discount_amount'] ?? 0) as num)
                                                      .toDouble(),
                                              roundOff: 0,
                                              taxEnabled: (data['tax'] ?? 0) > 0 || data['tax_enabled'] == 1,
                                              cgstPercent: ((data['cgst_percent'] ?? 0) as num).toDouble(),
                                              sgstPercent: ((data['sgst_percent'] ?? 0) as num).toDouble(),
                                              paymentType: data['payment_type'] ?? 'cash',
                                              orderType: _orderTypeText(data['orderType'] ?? data['order_type'] ?? ''),
                                              customerName: data['customerName'] ?? data['customer_name'],
                                              customerPhone: data['customerPhone'] ?? data['customer_phone'],
                                              customerGst: data['customerGst'] ?? data['customer_gst'],
                                              customerAddress: data['customerAddress'] ?? data['customer_address'],
                                              note: data['notes'] ?? data['customer_note'],
                                            ),
                                          ),
                                        );
                                      },
                                      onPrint: () {
                                        final rawItems = data['items'] as List<dynamic>? ?? [];
                                        final items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                                        _handlePrint(
                                          items: items,
                                          subTotal: ((data['totalAmount'] ?? data['subTotal'] ?? data['sub_total'] ?? 0)
                                                  as num)
                                              .toDouble(),
                                          customerName: data['customerName'] ?? data['customer_name'] ?? '',
                                          customerPhone: data['customerPhone'] ?? data['customer_phone'] ?? '',
                                          customerGst: data['customerGst'] ?? data['customer_gst'] ?? '',
                                          customerNote: data['notes'] ?? data['customer_note'] ?? '',
                                          customerAddress: data['customerAddress'] ?? data['customer_address'] ?? '',
                                          discountAmount:
                                              ((data['discount'] ?? data['discount_amount'] ?? 0) as num).toDouble(),
                                          discountPercent: ((data['discount_percent'] ?? 0) as num).toDouble(),
                                          receiptNo: data['billNumber']?.toString() ?? '',
                                          orderType: data['orderType'] ?? data['order_type'] ?? '',
                                          paymentType: data['payment_type'] ?? 'cash',
                                        );
                                      },
                                      onWhatsapp: () {
                                        final rawItems = data['items'] as List<dynamic>? ?? [];
                                        final items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                                        _handleWhatsapp(
                                          items: items,
                                          subTotal: ((data['totalAmount'] ?? data['subTotal'] ?? data['sub_total'] ?? 0)
                                                  as num)
                                              .toDouble(),
                                          finalAmount: ((data['finalAmount'] ??
                                                  data['final_total'] ??
                                                  data['sub_total'] ??
                                                  0) as num)
                                              .toDouble(),
                                          customerName: data['customerName'] ?? data['customer_name'] ?? '',
                                          customerPhone: data['customerPhone'] ?? data['customer_phone'] ?? '',
                                          receiptNo: data['billNumber']?.toString() ?? '',
                                          orderType: data['orderType'] ?? data['order_type'] ?? '',
                                          paymentType: data['payment_type'] ?? 'cash',
                                          dateTime: _parseToLocalDate(data['orderDate'] ?? data['created_at']),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 60),
                              ],
                            )
                    ],
                  ),
                ),
              ));
  }

  Widget _buildStatusToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: (_isShopOpen ? Colors.green : Colors.red).withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (_isShopOpen ? Colors.green : Colors.red).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isShopOpen)
            const _PulseDot(color: Colors.green)
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          MyText(
            text: _isShopOpen ? 'Live' : 'Closed',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _isShopOpen ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          _isToggling
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                  ),
                )
              : Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isShopOpen,
                    onChanged: _toggleShopStatus,
                    activeColor: Colors.green,
                    activeTrackColor: Colors.green.withOpacity(0.3),
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.withOpacity(0.3),
                  ),
                ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _animation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 8 * _animation.value,
              height: 8 * _animation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(1.0 - (_controller.value)),
              ),
            );
          },
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}

/// INFO CARD
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          border: Border.all(color: color, width: 0.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MyText(text: title, color: color, fontWeight: FontWeight.w600, fontSize: 18),
                        Icon(icon, color: color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MyText(
                      text: value,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                      overflow: TextOverflow.ellipsis,
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

class _SalesOverviewChart extends StatefulWidget {
  final List<dynamic> data;
  const _SalesOverviewChart({required this.data});

  @override
  State<_SalesOverviewChart> createState() => _SalesOverviewChartState();
}

class _SalesOverviewChartState extends State<_SalesOverviewChart> {
  bool isBarView = true;

  @override
  Widget build(BuildContext context) {
    double totalRevenue = widget.data.fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
    double avgRevenue = widget.data.isEmpty ? 0 : totalRevenue / widget.data.length;

    return Container(
      height: 320,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: AppLocale.revenueAnalysis.getString(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: MyText(
                          text: PriceUtils.formatPrice(totalRevenue.toInt()),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      MyText(
                        text: AppLocale.totalPeriod.getString(context),
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _ToggleIcon(
                      icon: Icons.bar_chart_rounded,
                      isActive: isBarView,
                      onTap: () => setState(() => isBarView = true),
                    ),
                    _ToggleIcon(
                      icon: Icons.show_chart_rounded,
                      isActive: !isBarView,
                      onTap: () => setState(() => isBarView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              child: isBarView ? _buildBarChart() : _buildAreaChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (widget.data.isEmpty) return Center(child: MyText(text: AppLocale.noDataAvailable.getString(context)));

    final maxAmount = widget.data.map((e) => (e['amount'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    final maxY = (maxAmount * 1.2).clamp(1000.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.black87,
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            tooltipMargin: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                PriceUtils.formatPrice(rod.toY.toInt()),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < widget.data.length) {
                  String date = widget.data[value.toInt()]['date'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: MyText(
                      text: date.substring(8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox();
                String label =
                    value.toInt() >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toInt().toString();
                return MyText(
                  text: label,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.04),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: widget.data.asMap().entries.map((e) {
          final amount = (e.value['amount'] as num).toDouble();
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: amount,
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withOpacity(0.6),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(20)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.grey.withOpacity(0.04),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAreaChart() {
    if (widget.data.isEmpty) return Center(child: MyText(text: AppLocale.noDataAvailable.getString(context)));

    final maxAmount = widget.data.map((e) => (e['amount'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    final maxY = (maxAmount * 1.2).clamp(1000.0, double.infinity);

    return LineChart(
      LineChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.04),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < widget.data.length) {
                  String date = widget.data[value.toInt()]['date'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: MyText(
                      text: date.substring(8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxY) return const SizedBox();
                String label =
                    value.toInt() >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toInt().toString();
                return MyText(
                  text: label,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: widget.data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), (e.value['amount'] as num).toDouble());
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.5,
            preventCurveOverShooting: true,
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
                primaryColor.withOpacity(0.6),
              ],
            ),
            barWidth: 5,
            isStrokeCapRound: true,
            shadow: Shadow(
              color: primaryColor.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.12),
                  primaryColor.withOpacity(0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black87,
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  PriceUtils.formatPrice(spot.y.toInt()),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleIcon({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? primaryColor : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _OrderDistributionChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final String businessCategory;
  const _OrderDistributionChart({required this.data, required this.businessCategory});

  @override
  Widget build(BuildContext context) {
    int total = data.values.fold(0, (acc, curr) => acc + (curr as int));
    if (total == 0) return const SizedBox();

    return Container(
      height: 270,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 45,
                    startDegreeOffset: -90,
                    sections: [
                      if (businessCategory == 'Food')
                        PieChartSectionData(
                          value: (data['DineIn'] ?? 0).toDouble(),
                          title: '',
                          color: Colors.teal.shade400,
                          radius: 18,
                          badgeWidget: _buildBadge(Icons.restaurant, Colors.teal),
                          badgePositionPercentageOffset: 0.98,
                        ),
                      if (businessCategory == 'Food')
                        PieChartSectionData(
                          value: (data['PickUp'] ?? 0).toDouble(),
                          title: '',
                          color: Colors.orange.shade400,
                          radius: 18,
                          badgeWidget: _buildBadge(Icons.shopping_bag, Colors.orange),
                          badgePositionPercentageOffset: 0.98,
                        ),
                      PieChartSectionData(
                        value: (data['Delivery'] ?? 0).toDouble(),
                        title: '',
                        color: Colors.red.shade400,
                        radius: 18,
                        badgeWidget: _buildBadge(Icons.delivery_dining, Colors.red),
                        badgePositionPercentageOffset: 0.98,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MyText(
                      text: total.toString(),
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    MyText(
                      text: AppLocale.ordersLabel.getString(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 25),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: AppLocale.distribution.getString(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
                const SizedBox(height: 18),
                if (businessCategory == 'Food')
                  _DistributionLegend(
                    label: AppLocale.dineIn.getString(context),
                    count: (data['DineIn'] ?? 0).toInt(),
                    color: Colors.teal.shade400,
                    percent: total > 0 ? (data['DineIn'] ?? 0) / total : 0,
                  ),
                if (businessCategory == 'Food')
                  _DistributionLegend(
                    label: AppLocale.pickUp.getString(context),
                    count: (data['PickUp'] ?? 0).toInt(),
                    color: Colors.orange.shade400,
                    percent: total > 0 ? (data['PickUp'] ?? 0) / total : 0,
                  ),
                _DistributionLegend(
                  label: AppLocale.delivery.getString(context),
                  count: (data['Delivery'] ?? 0).toInt(),
                  color: Colors.red.shade400,
                  percent: total > 0 ? (data['Delivery'] ?? 0) / total : 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 10, color: color),
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final double percent;

  const _DistributionLegend({
    required this.label,
    required this.count,
    required this.color,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MyText(
                  text: label,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              MyText(
                text: '${(percent * 100).toStringAsFixed(0)}%',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: MyText(
              text: '$count Orders',
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(child: _skeletonCard(height: 100)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonCard(height: 100)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _skeletonCard(height: 100)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonCard(height: 100)),
              ],
            ),
            const SizedBox(height: 15),
            // Filter section
            _skeletonCard(height: 120),
            const SizedBox(height: 20),
            // Chart section
            _skeletonCard(height: 250),
            const SizedBox(height: 20),
            // Orders list
            ...List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _skeletonCard(height: 80),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonCard({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
