import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/view/home/offline_bill_status_screen.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/reports/billWise_report.dart';
import 'package:pos/view/home/reports/customerWise_report.dart';
import 'package:pos/view/home/reports/dateWise_report.dart';
import 'package:pos/view/home/reports/itemWise_report.dart';
import 'package:pos/view/home/reports/sales_report_screen.dart';
import 'package:pos/view/home/screens/customer_list_screen.dart';
import 'package:pos/view/home/screens/dashboard.dart';
import 'package:pos/view/home/screens/edit_bill_receipt.dart';
import 'package:pos/view/home/screens/settings/setting_main.dart';
import 'package:pos/view/home/screens/users_data_screen.dart';
import 'package:pos/view/login/screens/inception_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/sync_status_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String adminUid = '';

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final phoneNo = widget.phoneNo;
    final sqliteHelper = SQLiteHelper();

    try {
      setState(() {
        isUserLoading = true;
      });

      // 1️⃣ Try local cache first
      final localData = await sqliteHelper.getUserData(phoneNo);

      if (localData != null) {
        if (mounted) {
          setState(() {
            userData = {
              'name': localData['name'] ?? 'User',
              'phoneNumber': localData['phoneNumber'] ?? phoneNo,
              'email': localData['email'],
              'adminUid': localData['adminUid'],
              'customerCode': localData['customerCode'],
              'shopName': localData['shopName'],
              'logoUrl': localData['shopLogoUrl'],
              'contact': localData['shopContact'],
              'address': localData['address'],
            };
            adminUid = localData['adminUid'] ?? '';
            isUserLoading = false;
          });
        }
        return;
      }

      // 2️⃣ Fetch from Firebase
      final doc = await FirebaseFirestore.instance
          .collection('AllAdmins')
          .doc(widget.adminPhoneNo)
          .collection('customer')
          .doc(phoneNo)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          await sqliteHelper.saveUserData({
            'phoneNumber': data['phoneNumber'] ?? widget.phoneNo,
            'adminUid': data['adminUid'] ?? widget.phoneNo,
            'shopName': data['shopName'],
            'logoUrl': data['logoUrl'],
            'contact': data['contact'],
            'address': data['address'],
            'name': data['name'],
            'email': data['email'],
            'customerCode': data['customerCode'],
            'gstNumber': data['gstNo'],
            'createdAt': data['createdAt'],
          });

          if (mounted) {
            setState(() {
              userData = data;
              adminUid = data['adminUid'] ?? '';
              isUserLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() => isUserLoading = false);
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
      if (mounted) {
        setState(() => isUserLoading = false);
      }
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
                      Container(
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
                                          color: primaryColor,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    // Handle network errors gracefully

                                    return Container(
                                      color: primaryColor,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: primaryColor,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${userData['shopName']}',
                                style: const TextStyle(
                                  fontFamily: 'tabfont',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  // fontSize: 17,

                                  letterSpacing: 1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${userData['phoneNumber']}',
                                style: const TextStyle(
                                  fontFamily: 'fontmain',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
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
                          Text(
                            printProvider.isConnected ? 'Printer Connected' : 'Printer Not Connected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: printProvider.isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                            ),
                          ),
                          if (printProvider.isConnected && printProvider.selectedPrinter != null)
                            Text(
                              printProvider.selectedPrinter!.deviceName ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
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
                title: Text(
                  printProvider.isConnected ? 'Disconnect Printer' : 'Connect Printer',
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
                          content: Text('Printer disconnected'),
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
            title: const Text('Dashboard'),
            onTap: () {
              _navigate(Dashboard(phoneNo: widget.phoneNo));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: primaryColor),
            title: const Text('My Customers'),
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
            title: const Text('Saved Orders'),
            onTap: () {
              _navigate(const UsersScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync, color: primaryColor),
            title: const Text('Offline Status & Bills'),
            onTap: () {
              _navigate(
                OfflineBillStatusScreen(
                  adminUid: adminUid,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_problem, color: primaryColor),
            title: const Text('Sync Diagnostics'),
            onTap: () {
              _navigate(
                SyncStatusPage(
                  adminUid: adminUid,
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(MdiIcons.chartBar, color: primaryColor),
            title: const Text('Sales Report'),
            onTap: () {
              _navigate(
                SalesReportScreen(
                  adminUid: widget.phoneNo,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people, color: primaryColor),
            title: const Text('Customerwise Report'),
            onTap: () {
              _navigate(
                CustomerWiseReport(
                  adminUid: adminUid,
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(MdiIcons.fileDocumentOutline, color: primaryColor),
            title: const Text('Billwise Report'),
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
            title: const Text('Itemwise Report'),
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
            title: const Text('Datewise Report'),
            onTap: () {
              _navigate(
                DatewiseReportScreen(
                  adminUid: adminUid,
                  uid: widget.phoneNo,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt, color: primaryColor),
            title: const Text('Edit bill Receipt'),
            onTap: () {
              _navigate(
                EditBillReceiptScreen(
                  AdminUid: widget.adminPhoneNo,
                  phoneNo: widget.phoneNo,
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings, color: primaryColor),
            title: const Text('Setting'),
            onTap: () {
              _navigate(
                Setting(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext) {
                  return Dialog(
                      // backgroundColor: Colors.amber.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)), //this right here
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const Text(
                                "Are you sure ?",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                    child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text(
                                      "Logout",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () async {
                                      SharedPreferences prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('isLogged', false);
                                      FirebaseAuth.instance.signOut();
                                      Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const Inception(),
                                          ));
                                    },
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ));
                },
              );
            },
          ),
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
