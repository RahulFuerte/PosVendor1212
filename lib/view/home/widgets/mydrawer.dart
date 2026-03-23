// Package imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/offline_bill_status_screen.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/reports/bill_wise_report.dart';
import 'package:pos/view/home/reports/customer_wise_report.dart';
import 'package:pos/view/home/reports/date_wise_report.dart';
import 'package:pos/view/home/reports/item_wise_report.dart';
import 'package:pos/view/home/reports/sales_report_screen.dart';
import 'package:pos/view/home/screens/expense_main.dart';
import 'package:pos/view/home/screens/customer_list_screen.dart';
import 'package:pos/view/home/screens/dashboard.dart';
import 'package:pos/view/home/screens/edit_bill_receipt.dart';
import 'package:pos/view/home/screens/settings/setting_main.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/login/screens/login.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/home/screens/Items/menu_screen.dart';
import 'package:pos/view/tab_screen/view-model/widgets/sync_status_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/data/datasources/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final status = prefs.getString('subscriptionStatus') ?? 'inactive';
      final planType = prefs.getString('subscriptionPlanType') ?? 'free';
      final endDateStr = prefs.getString('subscriptionEndDate');
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      context.read<SubscriptionProvider>().setExpiry(endDate, status: status, planType: planType);

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
        };
        adminUid = prefs.getString('adminUid') ?? '';
        isUserLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
                        onTap: () {
                          _navigate(EditBillReceiptScreen(
                            AdminUid: adminUid,
                            phoneNo: widget.phoneNo,
                          ));
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
                          onTap: () {
                            _navigate(EditBillReceiptScreen(
                              AdminUid: adminUid,
                              phoneNo: widget.phoneNo,
                            ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  text: '${userData['shopName']}',
                                  fontFamily: 'tabfont',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                const MyText(
                                  text: 'Edit Profile',
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
                            text: printProvider.isConnected ? 'Printer Connected' : 'Printer Not Connected',
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
                  text: printProvider.isConnected ? 'Disconnect Printer' : 'Connect Printer',
                ),
                onTap: () async {
                  if (printProvider.isConnected) {
                    // Disconnect printer
                    if (printProvider.selectedPrinter != null) {
                      await PrinterManager.instance.disconnect(
                        type: printProvider.selectedPrinter!.typePrinter,
                      );
                      printProvider.disconnectPrinter();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: MyText(text: 'Printer disconnected'),
                          backgroundColor: Colors.orange,
                        ),
                      );
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
          ListTile(
            leading: const Icon(Icons.dashboard, color: primaryColor),
            title: const MyText(text: 'Dashboard'),
            onTap: () {
              _navigate(Dashboard(
                adminUid: adminUid,
                phoneNo: widget.phoneNo,
                name: userData['shopName'],
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: primaryColor),
            title: const MyText(text: 'My Customers'),
            onTap: () {
              _navigate(
                CustomersListScreen(
                  adminUid: adminUid,
                  phoneNo: widget.phoneNo,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.save_as, color: primaryColor),
            title: const MyText(text: 'Saved Orders'),
            onTap: () {
              _navigate(UsersScreen(
                adminId: adminUid,
                uid: widget.phoneNo,
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu, color: primaryColor),
            title: const MyText(text: 'Menu'),
            onTap: () {
              _navigate(const MenuScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync, color: primaryColor),
            title: const MyText(text: 'Offline Status & Bills'),
            onTap: () {
              _navigate(
                OfflineBillStatusScreen(
                  adminUid: adminUid,
                  uid: widget.phoneNo,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_problem, color: primaryColor),
            title: const MyText(text: 'Sync Diagnostics'),
            onTap: () {
              _navigate(
                SyncStatusPage(
                  adminUid: adminUid,
                  uid: widget.phoneNo,
                ),
              );
            },
          ),

          Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(MdiIcons.chartBoxOutline, color: primaryColor),
              childrenPadding: const EdgeInsets.only(left: 16),
              title: const MyText(
                text: 'Reports',
              ),
              children: [
                ListTile(
                  leading: Icon(MdiIcons.chartBar, color: primaryColor),
                  title: const MyText(text: 'Sales Report'),
                  onTap: () {
                    _navigate(
                      SalesReportScreen(
                        adminUid: adminUid,
                        uid: widget.phoneNo,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: primaryColor),
                  title: const MyText(text: 'Customerwise Report'),
                  onTap: () {
                    _navigate(
                      CustomerWiseReport(
                        adminUid: adminUid,
                        uid: widget.phoneNo,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(MdiIcons.fileDocumentOutline, color: primaryColor),
                  title: const MyText(text: 'Billwise Report'),
                  onTap: () {
                    _navigate(
                      BillwiseReportScreen(
                        adminUid: adminUid,
                        uid: widget.phoneNo,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(MdiIcons.foodOutline, color: primaryColor),
                  title: const MyText(text: 'Itemwise Report'),
                  onTap: () {
                    _navigate(
                      ItemwiseReportScreen(
                        uid: widget.phoneNo,
                        adminUid: adminUid,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(MdiIcons.calendarMonth, color: primaryColor),
                  title: const MyText(text: 'Datewise Report'),
                  onTap: () {
                    _navigate(
                      DatewiseReportScreen(
                        adminUid: adminUid,
                        uid: widget.phoneNo,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: primaryColor),
            title: const MyText(text: 'Expenses'),
            onTap: () {
              _navigate(
                Expenses(uid: widget.phoneNo),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings, color: primaryColor),
            title: const MyText(text: 'Setting'),
            onTap: () {
              _navigate(
                const Setting(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const MyText(text: 'Log Out'),
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
                          const MyText(
                            text: "Confirm Logout",
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 12),
                          MyText(
                            text:
                                "Are you sure you want to logout? You will need to login again to access your account.",
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
                                    text: "Cancel",
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await MySharedPreferences().clear();
                                    if (context.mounted) {
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
                                  child: const MyText(
                                    text: "Logout",
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
          Consumer<SubscriptionProvider>(
            builder: (context, sub, _) {
              if (!sub.isInitialized) {
                return _subscriptionContainer(
                  iconColor: Colors.grey,
                  borderColor: Colors.grey,
                  bgColor: Colors.grey.shade200,
                  child: const MyText(text: 'Checking subscription...'),
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
                        text: sub.status == 'inactive' ? 'Subscription Inactive' : 'Subscription Expired',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      MyText(
                        text: 'Plan: ${sub.planType.toUpperCase()}',
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
                    MyText(
                      text: 'Plan: ${sub.planType.toUpperCase()}',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: appbar1,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    MyText(
                      text: sub.remaining == null ? 'Subscription Status' : 'Subscription Expires In',
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
        ],
      ),
    );
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
