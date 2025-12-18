import 'package:flutter/material.dart';

import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/local_DB/customerDB_helper.dart';
import 'package:pos/view/local_DB/customer_model.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomersListScreen extends StatefulWidget {
  final String adminUid;
  final String phoneNo;
  const CustomersListScreen({
    Key? key,
    required this.adminUid,
    required this.phoneNo,
  }) : super(key: key);

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  List<CustomerModel> customers = [];
  List<CustomerModel> notUploadedCustomers = [];
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);
    try {
      final allCustomers = await CustomerDatabase.instance.getAllCustomers();
      final notUploaded =
          await CustomerDatabase.instance.getNotUploadedCustomers();
      setState(() {
        customers = allCustomers;
        notUploadedCustomers = notUploaded;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadToFirebase() async {
    if (notUploadedCustomers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customers to upload'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      int successCount = 0;

      for (var customer in notUploadedCustomers) {
        try {
          // Generate receipt number
          final receiptNo = 'RCP${DateTime.now().millisecondsSinceEpoch}';

          // Create customer data
          final customerData = {
            'name': customer.name,
            'phone': customer.phone,
            'gstNo': customer.gstNo ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          };

          // Upload to Firebase: AllAdmins/{adminUid}/customers/{customerPhone}
          await firestore
              .collection('AllAdmins')
              .doc(widget.adminUid)
              .collection('customer')
              .doc(widget.phoneNo)
              .collection('myCustomers')
              .doc(customer.phone)
              .set(customerData, SetOptions(merge: true));

          // Mark as uploaded in local database
          await CustomerDatabase.instance.markAsUploaded(customer.id!);
          successCount++;
        } catch (e) {
          debugPrint('Error uploading customer ${customer.name}: $e');
        }
      }

      setState(() => isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded $successCount customers'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomers();
      }
    } catch (e) {
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await CustomerDatabase.instance.deleteCustomer(customer.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Customers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: appbar1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
        // actions: [
        //   if (notUploadedCustomers.isNotEmpty)
        //     Container(
        //       margin: const EdgeInsets.only(right: 8),
        //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        //       decoration: BoxDecoration(
        //         color: Colors.red,
        //         borderRadius: BorderRadius.circular(12),
        //       ),
        //       child: Center(
        //         child: Text(
        //           '${notUploadedCustomers.length}',
        //           style: const TextStyle(
        //             color: Colors.white,
        //             fontWeight: FontWeight.bold,
        //           ),
        //         ),
        //       ),
        //     ),
        // ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 100,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Customers Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Stats Card
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appbar1.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appbar1.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${customers.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: appbar1,
                                ),
                              ),
                              const Text('Total'),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[400],
                          ),
                          Column(
                            children: [
                              Text(
                                '${notUploadedCustomers.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Text('Not Synced'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Customer List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: customer.isUploaded
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                child: Icon(
                                  customer.isUploaded
                                      ? Icons.cloud_done
                                      : Icons.cloud_upload,
                                  color: customer.isUploaded
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('📱 ${customer.phone}'),
                                  if (customer.gstNo != null &&
                                      customer.gstNo!.isNotEmpty)
                                    Text('📄 GST: ${customer.gstNo}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(customer.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCustomer(customer),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: notUploadedCustomers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: isUploading ? null : _uploadToFirebase,
              backgroundColor: appbar1,
              icon: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                isUploading
                    ? 'Uploading...'
                    : 'Sync ${notUploadedCustomers.length} Customers',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
