// Package imports:
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/offline_bill_status_screen.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/reports/bill_wise_report.dart'; 
import 'package:pos/view/home/reports/customer_wise_report.dart';
import 'package:pos/view/home/reports/date_wise_report.dart';
import 'package:pos/view/home/reports/item_wise_report.dart';
import 'package:pos/view/home/reports/sales_report_screen.dart';
import 'package:pos/view/home/reports/staff_wise_report.dart';
import 'package:pos/view/home/screens/expense_main.dart';
import 'package:pos/view/home/screens/customer_list_screen.dart';
import 'package:pos/view/home/screens/dashboard.dart';
import 'package:pos/view/home/screens/edit_bill_receipt.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/data/providers/login_provider.dart';
import 'package:pos/view/home/screens/table_management_screen.dart';
import 'package:pos/view/login/login.dart';
import 'package:pos/view/home/screens/kot_management_screen.dart';
import 'package:pos/view/home/screens/order_management_screen.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:pos/view/home/screens/settings/setting_main.dart';
import 'package:pos/view/login/language_selection_screen.dart';

import 'package:pos/view/staff/screens/staff_list_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/home/screens/Items/menu_screen.dart';
import 'package:pos/view/tab_screen/view-model/widgets/sync_status_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/view/home/screens/subscription_plans_screen.dart';
import 'package:pos/data/services/user_service.dart';

class MyDrawer extends StatefulWidget {
  final String phoneNo;
  final String adminPhoneNo;
  const MyDrawer({
    super.key,
    required this.phoneNo,
    required this.adminPhoneNo,
  });

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  Map<String, dynamic> userData = {};
  bool isUserLoading = true;
  String adminUid = '';
  String userRole = '';
  bool _tourShowing = false;
  TutorialCoachMark? _tourMark;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TourProvider>().addListener(_onTourStateChanged);
      _onTourStateChanged();
    });
  }

  @override
  void dispose() {
    try {
      context.read<TourProvider>().removeListener(_onTourStateChanged);
    } catch (_) {}
    _tourMark?.finish();
    super.dispose();
  }

  void _onTourStateChanged() {
    if (!mounted) return;
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    if (tourProvider.isTourActive && tourProvider.currentStep == 30 && !_tourShowing) {
      _tourShowing = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && tourProvider.isTourActive && tourProvider.currentStep == 30) {
          _showTour();
        } else {
          _tourShowing = false;
        }
      });
    }
  }

  void _showTour() {
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final targets = [
      TargetFocus(
        identify: "drawer_settings",
        keyTarget: TourKeys.drawerSettingsKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 30,
                title: AppLocale.settings.getString(context),
                description: AppLocale.tourDesc23.getString(context),
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
    ];

    final validTargets = targets.where((t) {
      final k = t.keyTarget;
      return k == null || k.currentContext != null;
    }).toList();
    if (validTargets.isEmpty) {
      _tourShowing = false;
      if (tourProvider.isTourActive) {
        tourProvider.setStep(31);
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Setting()),
        );
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
        _tourShowing = false;
        if (tourProvider.isTourActive) {
          tourProvider.setStep(31);
          Navigator.of(context).pop();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Setting()),
          );
        }
      },
      onSkip: () {
        _tourShowing = false;
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final status = prefs.getString('subscriptionStatus') ?? 'inactive';
      final planType = prefs.getString('subscriptionPlanType') ?? 'free';
      final planId = prefs.getString('subscriptionPlanId');
      final endDateStr = prefs.getString('subscriptionEndDate');
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      context.read<SubscriptionProvider>().setExpiry(endDate, status: status, planType: planType, planId: planId);

      setState(() {
        userData = {
          'name': prefs.getString('name') ?? 'User',
          'phoneNumber': prefs.getString('phoneNumber') ?? widget.phoneNo,
          'email': prefs.getString('email'),
          'adminUid': prefs.getString('adminUid'),
          'customerCode': prefs.getString('customerCode'),
          'shopName': prefs.getString('shopName') ?? 'Shop Name',
          'logoUrl': prefs.getString('logoUrl'),
          'contact': prefs.getString('contact'),
          'address': prefs.getString('address'),
          'upiId': prefs.getString('upiId'),
          'fssaiNo': prefs.getString('fssaiNo'),
          'role': prefs.getString('role'),
          'businessCategory': prefs.getString('businessCategory') ?? 'Food',
        };
        adminUid = prefs.getString('adminUid') ?? '';
        userRole = prefs.getString('role') ?? '';
        isUserLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    return Drawer(
        child: RepaintBoundary(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
              decoration: const BoxDecoration(
                color: primaryColor,
              ),
              child: isUserLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Row(
                      children: [
                        GestureDetector(
                          onTap: userRole == 'staff'
                              ? null
                              : () {
                                  _navigate(const EditBillReceiptScreen());
                                },
                          child: Container(
                            height: 90,
                            width: 90,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(75),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(75),
                              child: userData['logoUrl'] != null && userData['logoUrl'].toString().isNotEmpty
                                  ? Image.network(
                                      userData['logoUrl'],
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: primaryColor,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: primaryColor.withOpacity(0.8),
                                          child: const Icon(
                                            Icons.storefront_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: primaryColor.withOpacity(0.8),
                                      child: const Icon(
                                        Icons.storefront_rounded,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: userRole == 'staff'
                                ? null
                                : () {
                                    _navigate(const EditBillReceiptScreen());
                                  },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyText(
                                    text: '${userData['shopName']}',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  MyText(
                                    text: AppLocale.editProfile.getString(context),
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

          // Printer Connection Status
          Consumer<PrintProvider>(
            builder: (context, printProvider, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: printProvider.isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: printProvider.isConnected ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      printProvider.isConnected ? Icons.check_circle : Icons.print_disabled,
                      color: printProvider.isConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: printProvider.isConnected
                                ? AppLocale.printerConnected.getString(context)
                                : AppLocale.printerNotConnected.getString(context),
                            fontWeight: FontWeight.bold,
                            color: printProvider.isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                          if (printProvider.isConnected && printProvider.selectedPrinter != null)
                            MyText(
                              text: printProvider.selectedPrinter!.deviceName ?? 'Unknown',
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Connect/Disconnect Printer
          Consumer<PrintProvider>(
            builder: (context, printProvider, child) {
              return ListTile(
                leading: Icon(
                  printProvider.isConnected ? Icons.link_off : Icons.link,
                  color: printProvider.isConnected ? Colors.red : Colors.blue,
                ),
                title: MyText(
                  text: printProvider.isConnected
                      ? AppLocale.disconnectPrinter.getString(context)
                      : AppLocale.connectPrinter.getString(context),
                ),
                onTap: () async {
                  if (printProvider.isConnected) {
                    // Disconnect printer
                    if (printProvider.selectedPrinter != null) {
                      await PrinterManager.instance.disconnect(
                        type: printProvider.selectedPrinter!.typePrinter,
                      );
                      printProvider.disconnectPrinter();
                      SnackBarUtils.showWarning(context, AppLocale.printerDisconnected.getString(context));
                    }
                  } else {
                    // Show connection dialog
                    Navigator.pop(context); // Close drawer
                    showDialog(
                      context: context,
                      builder: (context) => const PrinterConnectionDialog(),
                    );
                  }
                },
              );
            },
          ),
          const Divider(),
          Visibility(
            visible: sub.hasPermission('Dashboard', checkView: true),
            child: ListTile(
              leading: const Icon(Icons.dashboard, color: primaryColor),
              title: MyText(fontWeight: FontWeight.w500, text: AppLocale.dashboard.getString(context)),
              onTap: () {
                _navigate(const Dashboard());
              },
            ),
          ),
          Visibility(
            visible: sub.hasPermission('TableBooking', checkView: true) && userData['businessCategory'] == 'Food',
            child: ListTile(
              leading: const Icon(Icons.table_restaurant, color: primaryColor),
              title: MyText(fontWeight: FontWeight.w500, text: AppLocale.tableBooking.getString(context)),
              onTap: () {
                _navigate(const TableManagementScreen());
              },
            ),
          ),
          Visibility(
            visible: sub.hasPermission('OrderManagement', checkView: true),
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: primaryColor),
              title: MyText(fontWeight: FontWeight.w500, text: AppLocale.orderManagement.getString(context)),
              onTap: () {
                _navigate(const OrderManagementScreen());
              },
            ),
          ),
          Visibility(
            visible: sub.hasPermission('KitchenOrders', checkView: true) && userData['businessCategory'] == 'Food',
            child: ListTile(
              leading: const Icon(Icons.kitchen, color: primaryColor),
              title: MyText(fontWeight: FontWeight.w500, text: AppLocale.kitchenOrdersKot.getString(context)),
              onTap: () {
                _navigate(const KotManagementScreen());
              },
            ),
          ),
          Visibility(
            visible: sub.hasPermission('MyCustomers', checkView: true),
            child: ListTile(
              leading: const Icon(Icons.person, color: primaryColor),
              title: MyText(fontWeight: FontWeight.w500, text: AppLocale.myCustomers.getString(context)),
              onTap: () {
                _navigate(const CustomersListScreen());
              },
            ),
          ),
          if (userRole != 'staff') ...[
            Visibility(
              visible: sub.hasPermission('StaffManagement', checkView: true),
              child: ListTile(
                leading: const Icon(Icons.people, color: primaryColor),
                title: MyText(fontWeight: FontWeight.w500, text: AppLocale.staffManagement.getString(context)),
                onTap: () {
                  _navigate(const StaffListScreen());
                },
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.save_as, color: primaryColor),
            title: MyText(fontWeight: FontWeight.w500, text: AppLocale.savedOrders.getString(context)),
            onTap: () {
              _navigate(const UsersScreen());
            },
          ),
          Visibility(
            visible: sub.hasPermission('Menu', checkView: true),
            child: ListTile(
              leading: Icon(
                  userData['businessCategory'] == 'Food' ? Icons.restaurant_menu : Icons.inventory_2_outlined,
                  color: primaryColor),
              title: MyText(
                  fontWeight: FontWeight.w500,
                  text: userData['businessCategory'] == 'Food'
                      ? AppLocale.menu.getString(context)
                      : AppLocale.products.getString(context)),
              onTap: () {
                _navigate(const MenuScreen());
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync, color: primaryColor),
            title: MyText(fontWeight: FontWeight.w500, text: AppLocale.offlineStatusBills.getString(context)),
            onTap: () {
              _navigate(const OfflineBillStatusScreen());
            },
          ),
          if (userRole != 'staff') ...[
            ListTile(
              leading: const Icon(Icons.sync_problem, color: primaryColor),
              title: MyText(fontWeight: FontWeight.w500, text: AppLocale.syncDiagnostics.getString(context)),
              onTap: () {
                _navigate(const SyncStatusPage());
              },
            ),
          ],

          if (userRole != 'staff') ...[
            Visibility(
              visible: sub.hasPermission('Reports', checkView: true),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(MdiIcons.chartBoxOutline, color: primaryColor),
                  childrenPadding: const EdgeInsets.only(left: 16),
                  title: MyText(
                    text: AppLocale.reports.getString(context),
                  ),
                  children: [
                    ListTile(
                      leading: Icon(MdiIcons.chartBar, color: primaryColor),
                      title: MyText(fontWeight: FontWeight.w500, text: AppLocale.salesReport.getString(context)),
                      onTap: () {
                        _navigate(const SalesReportScreen());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.people, color: primaryColor),
                      title: MyText(fontWeight: FontWeight.w500, text: AppLocale.customerwiseReport.getString(context)),
                      onTap: () {
                        _navigate(const CustomerWiseReport());
                      },
                    ),
                    ListTile(
                      leading: Icon(MdiIcons.fileDocumentOutline, color: primaryColor),
                      title: MyText(fontWeight: FontWeight.w500, text: AppLocale.billwiseReport.getString(context)),
                      onTap: () {
                        _navigate(const BillwiseReportScreen());
                      },
                    ),
                    ListTile(
                      leading: Icon(MdiIcons.foodOutline, color: primaryColor),
                      title: MyText(fontWeight: FontWeight.w500, text: AppLocale.itemwiseReport.getString(context)),
                      onTap: () {
                        _navigate(const ItemwiseReportScreen());
                      },
                    ),
                    ListTile(
                      leading: Icon(MdiIcons.calendarMonth, color: primaryColor),
                      title: MyText(fontWeight: FontWeight.w500, text: AppLocale.datewiseReport.getString(context)),
                      onTap: () {
                        _navigate(const DatewiseReportScreen());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined, color: primaryColor),
                      title: MyText(fontWeight: FontWeight.w500, text: AppLocale.staffWiseReport.getString(context)),
                      onTap: () {
                        _navigate(const StaffWiseReportScreen());
                      },
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: sub.hasPermission('Expenses', checkView: true),
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: primaryColor),
                title: MyText(fontWeight: FontWeight.w500, text: AppLocale.expenses.getString(context)),
                onTap: () {
                  _navigate(const Expenses());
                },
              ),
            ),
          ],

          ListTile(
            key: TourKeys.drawerSettingsKey,
            leading: const Icon(Icons.settings, color: primaryColor),
            title: MyText(
              fontWeight: FontWeight.w500,
              text: AppLocale.settings.getString(context),
            ),
            onTap: () {
              _navigate(const Setting());
            },
          ),

          ListTile(
            leading: const Icon(Icons.language_rounded, color: primaryColor),
            title: MyText(
              fontWeight: FontWeight.w500,
              text: AppLocale.selectLanguage.getString(context),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MyText(
                text: FlutterLocalization.instance.currentLocale?.languageCode.toUpperCase() ?? 'EN',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(isFirstLaunch: false),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: MyText(fontWeight: FontWeight.w500, text: AppLocale.logout.getString(context)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.logout, color: Colors.red, size: 32),
                          ),
                          const SizedBox(height: 24),
                          MyText(
                            text: AppLocale.confirmLogout.getString(context),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 12),
                          MyText(
                            text: AppLocale.logoutConfirmMsg.getString(context),
                            textAlign: TextAlign.center,
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: MyText(
                                    text: AppLocale.cancel.getString(context),
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    // 1. Clear database and prefs
                                    await UserService().logout();

                                    // 2. Reset all providers in memory to clear UI state
                                    if (context.mounted) {
                                      context.read<TableProvider>().clearAll();
                                      context.read<PrintProvider>().reset();
                                      context.read<SubscriptionProvider>().reset();
                                      context.read<OrderTypeProvider>().reset();
                                      context.read<LoginProvider>().reset();

                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(builder: (context) => const Login()),
                                        (route) => false,
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: MyText(
                                    text: AppLocale.logout.getString(context),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          GestureDetector(
            onTap: () {
              _navigate(const SubscriptionPlansScreen());
            },
            child: Consumer<SubscriptionProvider>(
              builder: (context, sub, _) {
                if (!sub.isInitialized) {
                  return _subscriptionContainer(
                    iconColor: Colors.grey,
                    borderColor: Colors.grey,
                    bgColor: Colors.grey.shade200,
                    child: MyText(text: AppLocale.checkingSubscription.getString(context)),
                  );
                }

                if (sub.status == 'inactive' || sub.isExpired) {
                  return _subscriptionContainer(
                    iconColor: Colors.red,
                    borderColor: Colors.red,
                    bgColor: Colors.red.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MyText(
                          text: sub.status == 'inactive'
                              ? AppLocale.subscriptionInactive.getString(context)
                              : AppLocale.subscriptionExpired.getString(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                        MyText(
                          text: '${AppLocale.plan.getString(context)}: ${sub.planType.toUpperCase()}',
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  );
                }

                return _subscriptionContainer(
                  iconColor: appbar1,
                  borderColor: appbar1,
                  bgColor: appbar1.withOpacity(0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars, color: appbar1, size: 16),
                          const SizedBox(width: 8),
                          MyText(
                            text: '${AppLocale.plan.getString(context)}: ${sub.planType.toUpperCase()}',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: appbar1,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      MyText(
                        text: sub.remaining == null
                            ? AppLocale.subscriptionStatus.getString(context)
                            : AppLocale.subscriptionExpiresIn.getString(context),
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      MyText(
                        text: sub.remaining == null ? 'LIFE TIME' : sub.formattedTime,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: appbar1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _subscriptionContainer({
    required Color iconColor,
    required Color borderColor,
    required Color bgColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: iconColor, size: 30),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _navigate(Widget page) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 250), () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    });
  }
}
