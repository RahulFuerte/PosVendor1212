// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Project imports:
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/local_DB/customerDB_helper.dart';
import 'package:pos/view/local_DB/customer_model.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

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
      // Load local customers
      final allCustomers = await CustomerDatabase.instance.getAllCustomers();
      final notUploaded =
          await CustomerDatabase.instance.getNotUploadedCustomers();
      
      // Load customers from Firebase
      final firebaseCustomers = await _loadCustomersFromFirebase();
      
      // Merge local and Firebase customers (avoid duplicates)
      final mergedCustomers = <String, CustomerModel>{};
      
      // Add local customers first
      for (var customer in allCustomers) {
        mergedCustomers[customer.phone] = customer;
      }
      
      // Add Firebase customers (only if not already in local)
      for (var customer in firebaseCustomers) {
        if (!mergedCustomers.containsKey(customer.phone)) {
          mergedCustomers[customer.phone] = customer;
        }
      }
      
      setState(() {
        customers = mergedCustomers.values.toList();
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
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  Future<List<CustomerModel>> _loadCustomersFromFirebase() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
              .collection('AllAdmins')
              .doc(widget.adminUid)
              .collection('customer')
              .doc(widget.phoneNo)
              .collection('myCustomers')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CustomerModel(
          name: data['name'] ?? '',
          phone: doc.id,
          gstNo: data['gstNo']?.isEmpty == true ? null : data['gstNo'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isUploaded: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading customers from Firebase: $e');
      return [];
    }
  }

  Future<void> _uploadToFirebase() async {
    if (notUploadedCustomers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customers to upload'),
          backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.fixed,
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
                    behavior: SnackBarBehavior.fixed,
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
            behavior: SnackBarBehavior.fixed,
              ),
        );
      }
    }
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                          ),
        title: const Row(
                    children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Customer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                                    ],
                                  ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
            'Are you sure you want to delete ${customer.name}? This action cannot be undone.',
            style: const TextStyle(fontSize: 16),
                                        ),
                                        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                  ),
            child: const Text(
              'Cancel',
                        style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                            ),
                      ),
                  ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                      ),
                    ),
            child: const Text(
              'Delete',
                                style: TextStyle(
                fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
      ),
    );

    if (confirm == true) {
      try {
        await CustomerDatabase.instance.deleteCustomer(customer.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Customer deleted successfully',
                  style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
                      ),
    );
        _loadCustomers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error deleting: $e',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
  }
}
  }
  Future<void> _showAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final gstController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: appbar1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_add,
                color: appbar1,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Customer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person, color: appbar1),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone, color: appbar1),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: gstController,
                    decoration: InputDecoration(
                      labelText: 'GST Number (Optional)',
                      prefixIcon: Icon(Icons.receipt_long, color: appbar1),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Please fill in required fields',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.fixed,
                  ),
                );
                return;
              }

              try {
                final customer = CustomerModel(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  gstNo: gstController.text.trim().isEmpty
                      ? null
                      : gstController.text.trim(),
                  createdAt: DateTime.now(),
                  isUploaded: false,
                );

                await CustomerDatabase.instance.insertCustomer(customer);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Customer added successfully',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.fixed,
                  ),
                );
                _loadCustomers();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Error adding customer: $e',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.fixed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appbar1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add Customer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text(
          'Customers',
          style: TextStyle(
            fontFamily: 'tabfont',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (notUploadedCustomers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${notUploadedCustomers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading customers...',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'fontmain',
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Customers Yet',
                        style: TextStyle(
                          fontSize: 22,
                          fontFamily: 'tabfont',
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first customer to get started',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'fontmain',
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Enhanced Stats Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.people,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${customers.length}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontFamily: 'tabfont',
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Total Customers',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'fontmain',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_off,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${notUploadedCustomers.length}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontFamily: 'tabfont',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Not Synced',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'fontmain',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Enhanced Customer List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: customer.isUploaded
                                      ? primaryColor.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  customer.isUploaded
                                      ? Icons.cloud_done
                                      : Icons.cloud_upload,
                                  color: customer.isUploaded
                                      ? primaryColor
                                      : Colors.orange,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontFamily: 'tabfont',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        customer.phone,
                                        style: const TextStyle(
                                          fontFamily: 'fontmain',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (customer.gstNo != null &&
                                      customer.gstNo!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'GST: ${customer.gstNo}',
                                          style: const TextStyle(
                                            fontFamily: 'fontmain',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        dateFormat.format(customer.createdAt),
                                        style: TextStyle(
                                          fontFamily: 'fontmain',
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: customer.id != null ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteCustomer(customer),
                                ),
                              ) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "addCustomer",
            onPressed: _showAddCustomerDialog,
            backgroundColor: primaryColor,
            elevation: 4,
            child: const Icon(Icons.person_add, color: Colors.white, size: 28),
          ),
          if (notUploadedCustomers.isNotEmpty) ...[
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: "syncCustomers",
              onPressed: isUploading ? null : _uploadToFirebase,
              backgroundColor: primaryColor,
              elevation: 4,
              icon: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload, size: 24),
              label: Text(
                isUploading
                    ? 'Syncing...'
                    : 'Sync ${notUploadedCustomers.length} Customer${notUploadedCustomers.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'tabfont',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
