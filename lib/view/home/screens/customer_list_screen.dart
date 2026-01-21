import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/models/customer_model.dart';
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
  List<CustomerModel> filteredCustomers = [];
  bool isLoading = true;
  bool isUploading = false;
  bool isImporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);

    try {
      // 1️⃣ Load local customers
      final allCustomers = await SQLiteHelper().getAllCustomers();

      final localCustomers = allCustomers.map((customerMap) {
        return CustomerModel(
          id: null,
          name: customerMap['name'] ?? '',
          phone: customerMap['mobile_no'] ?? '',
          gstNo: customerMap['gst_no'] ?? "",
          address: customerMap['address'] ?? '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(customerMap['created_at']),
          isUploaded: false, // local by default
        );
      }).toList();

      // 2️⃣ Load Firebase customers
      final firebaseCustomers = await _loadCustomersFromFirebase();

      // 3️⃣ Index Firebase customers by phone
      final firebaseMap = {for (var c in firebaseCustomers) c.phone: c};

      final List<CustomerModel> mergedList = [];
      final List<CustomerModel> pendingSync = [];

      // 4️⃣ Merge + detect NOT uploaded customers
      for (final local in localCustomers) {
        if (firebaseMap.containsKey(local.phone)) {
          mergedList.add(
            local.copyWith(isUploaded: true),
          );
        } else {
          mergedList.add(local);
          pendingSync.add(local); 
        }
      }

      // 5️⃣ Add Firebase-only customers
      for (final fb in firebaseCustomers) {
        if (!mergedList.any((c) => c.phone == fb.phone)) {
          mergedList.add(fb.copyWith(isUploaded: true));
        }
      }

      setState(() {
        customers = mergedList;
        notUploadedCustomers = pendingSync; 
        filteredCustomers = mergedList; // Initialize filtered list
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

  Future<void> _importCustomersFromExcel() async {
    // Show a simplified info dialog first, then show the detailed help
    final shouldShowHelp = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 12),
            Text(
              'Import Customers',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Need help with Excel format? View detailed instructions first.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip Help'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: const Text(
              'Show Help',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    // Show detailed help if requested
    if (shouldShowHelp == true) {
      _showExcelFormatHelp();
      return; // Exit here since help dialog handles further flow
    }
    
    // If user skips help or closes it, proceed with import

    try {
      setState(() {
        isImporting = true;
      });

      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        PlatformFile file = result.files.single;
        
        // Show progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Importing customers...',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'fontmain',
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Processing ${file.name}',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'fontmain',
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Read and parse Excel file
        var bytes = File(file.path!).readAsBytesSync();
        var excelFile = excel.Excel.decodeBytes(bytes);
        
        List<CustomerModel> importedCustomers = [];
        int successfulImports = 0;
        int failedImports = 0;
        List<String> errors = [];
        
        // Check if Excel file has any worksheets
        if (excelFile.tables.isEmpty) {
          errors.add('No worksheets found in the Excel file');
          throw Exception('Invalid Excel file: ${errors.join(', ')}');
        }
        
        for (var table in excelFile.tables.keys) {
          var tableData = excelFile.tables[table]!;
          
          // Skip header row if exists
          for (int i = 0; i < tableData.rows.length; i++) {
            var row = tableData.rows[i];
            
            // Skip header row (first row)
            if (i == 0) {
              // Validate header row format
              if (row.length < 2) {
                errors.add('Invalid Excel format: Need at least Name and Phone columns');
                throw Exception('Invalid Excel format: ${errors.join(', ')}');
              }
              continue;
            }
            
            // Check if row has enough columns
            if (row.length < 2) {
              errors.add('Row ${i + 1}: Insufficient data (need at least Name and Phone)');
              failedImports++;
              continue;
            }
            
            // Extract data from columns (assuming A, B, C, D are name, phone, address, GST)
            String name = row[0]?.value?.toString()?.trim() ?? '';
            String phone = row[1]?.value?.toString()?.trim() ?? '';
            String address = row.length > 2 ? (row[2]?.value?.toString()?.trim() ?? '') : '';
            String gstNo = row.length > 3 ? (row[3]?.value?.toString()?.trim() ?? '') : '';
            
            // Validate required fields
            if (name.isEmpty || phone.isEmpty) {
              errors.add('Row ${i + 1}: Name and Phone are required');
              failedImports++;
              continue;
            }
            
            // Validate phone number format (basic validation)
            if (!_isValidPhoneNumber(phone)) {
              errors.add('Row ${i + 1}: Invalid phone number format (${phone})');
              failedImports++;
              continue;
            }
            
            // Check for duplicates
            if (customers.any((customer) => customer.phone == phone)) {
              errors.add('Row ${i + 1}: Duplicate phone number found (${phone})');
              failedImports++;
              continue;
            }
            
            // Create customer model
            CustomerModel customer = CustomerModel(
              name: name,
              phone: phone,
              address: address.isEmpty ? null : address,
              gstNo: gstNo.isEmpty ? null : gstNo,
              createdAt: DateTime.now(),
              isUploaded: false,
            );
            
            importedCustomers.add(customer);
            successfulImports++;
          }
        }
        
        // Close progress dialog
        Navigator.of(context).pop();
        
        // Insert customers into database
        if (importedCustomers.isNotEmpty) {
          for (var customer in importedCustomers) {
            try {
              await SQLiteHelper().saveCustomerData(customer.toMap());
            } catch (e) {
              errors.add('Failed to save customer ${customer.name}: $e');
              failedImports++;
              successfulImports--;
            }
          }
        }
        
        // Reload customers
        await _loadCustomers();
        
        // Show result
        String resultMessage = 'Import completed!\nSuccessful: $successfulImports, Failed: $failedImports';
        if (errors.isNotEmpty) {
          resultMessage += '\n\nErrors:\n${errors.take(3).join('\n')}';
          if (errors.length > 3) {
            resultMessage += '\n...and ${errors.length - 3} more';
          }
        }
        
        // Show result with option to sync to Firebase
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  successfulImports > 0 ? Icons.check_circle : Icons.warning,
                  color: successfulImports > 0 ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  successfulImports > 0 ? 'Import Complete' : 'Import Failed',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resultMessage),
                  if (successfulImports > 0)
                    const SizedBox(height: 16),
                  if (successfulImports > 0)
                    Text(
                      'Would you like to sync the imported customers to the cloud?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                ],
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
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (successfulImports > 0)
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Sync only the newly imported customers
                    await _uploadToFirebase();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    foregroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: primaryColor),
                    ),
                  ),
                  child: const Text(
                    'Sync Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isImporting = false;
      });
    }
  }

  bool _isValidPhoneNumber(String phone) {
    // Basic validation: check if it contains only numbers and has reasonable length
    RegExp phoneRegex = RegExp(r'^[0-9+\-().\s]+$');
    return phoneRegex.hasMatch(phone) && phone.length >= 7 && phone.length <= 15;
  }

  Future<void> downloadExcelFromFirebase() async {
  try {
    // 1. Reference the file in your screenshot
    // Path: sample_data/Sample Customer Data Generation.xlsx
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('sample_data/Sample Customer Data Generation.xlsx');

    // 2. Get the temporary public URL
    String url = await ref.getDownloadURL();

    // 3. Prepare the local path (Downloads folder for Android)
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    String fullPath = "${downloadsDir!.path}/Sample_Data.xlsx";

    // 4. Use Dio to download the file directly to that path
    // await Dio().download(url, fullPath);

    print("Download Complete: $fullPath");

    // 5. Optional: Open the file immediately for the user
    // OpenFilex.open(fullPath);

  } catch (e) {
    print("Error downloading file: $e");
  }
}

Future<void> downloadExcelWithHttp() async {
  // Ask user for confirmation first
  final shouldDownload = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(Icons.download, color: Colors.blue),
          SizedBox(width: 12),
          Text(
            'Download Sample Data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will download a sample Excel template to your device.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 12),
          Text(
            'After download, you can select this file when importing customers.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
          ),
          child: const Text(
            'Download',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (shouldDownload != true) return;

  try {
    // Show download progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
              const SizedBox(height: 24),
              const Text(
                'Downloading sample data...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1. Get the Download URL from Firebase
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('sample_data/Sample Customer Data Generation.xlsx');
    String url = await ref.getDownloadURL();

    // 2. Fetch the file data using http
    final response = await http.get(Uri.parse(url));

    // Close progress dialog
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (response.statusCode == 200) {
      // 3. Get the local storage path
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      String fullPath = "${downloadsDir.path}/Sample_Customer_Data.xlsx";
      File file = File(fullPath);

      // 4. Write the bytes to the file
      await file.writeAsBytes(response.bodyBytes);

      // Show success message with file name
      final fileName = fullPath.split('/').last;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Downloaded: $fileName\nYou can now select this file for import',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Download failed: ${response.statusCode}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // Close progress dialog if still open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Download error: $e',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  void _showExcelFormatHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 12),
            Text(
              'Excel Format Guide',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Excel file should have the following column structure:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Column A: Customer Name (Required)', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Column B: Phone Number (Required)', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Column C: Address (Optional)', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Column D: GST Number (Optional)', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Example:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('John Doe | 9876543210 | 123 Main St | GST123ABC'),
                    Text('Jane Smith | 9876543211 | 456 Oak Ave | '),
                    Text('Bob Johnson | 9876543212 | 789 Pine Rd | GST456DEF'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Make sure to remove any extra columns or rows before uploading.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: If you have no data then download a sample data by clicking on the "Download Sample" button.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => downloadExcelWithHttp(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Download Sample',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
          address: data['address'],
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
    

          // Create customer data
          final customerData = {
            'name': customer.name,
            'phone': customer.phone,
            'gstNo': customer.gstNo ?? '',
            'address': customer.address ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          };
          print("These Is Customer Data ...............$customerData");
          // Upload to Firebase: AllAdmins/{adminUid}/customers/{customerPhone}
          await firestore
              .collection('AllAdmins')
              .doc(widget.adminUid)
              .collection('customer')
              .doc(widget.phoneNo)
              .collection('myCustomers')
              .doc(customer.phone)
              .set(customerData, SetOptions(merge: true));

          // Customer is already considered uploaded in the unified database
          // No action needed for marking as uploaded
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
        await SQLiteHelper().deleteCustomerData(customer.phone);
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
    final addressController = TextEditingController();
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
              child: const Icon(
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
                      prefixIcon: const Icon(Icons.person, color: appbar1),
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
                      prefixIcon: const Icon(Icons.phone, color: appbar1),
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
                    controller: addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Customer Address *',
                      prefixIcon: const Icon(Icons.home, color: appbar1),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    keyboardType: TextInputType.text,
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
                      prefixIcon: const Icon(Icons.receipt_long, color: appbar1),
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
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
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
                  gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                  createdAt: DateTime.now(),
                  isUploaded: false,
                );

                await SQLiteHelper().saveCustomerData(customer.toMap());
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

  Future<void> _showEditCustomerBottomSheet(CustomerModel customer) async {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final gstController = TextEditingController(text: customer.gstNo ?? '');
    final addressController = TextEditingController(text: customer.address ?? '');
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Edit Customer',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputField(
                  controller: nameController,
                  label: 'Customer Name *',
                  icon: Icons.person,
                  hint: 'Enter customer name',
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: phoneController,
                  label: 'Phone Number *',
                  icon: Icons.phone,
                  hint: 'Enter phone number',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: addressController,
                  label: 'Customer Address',
                  icon: Icons.home,
                  hint: 'Enter customer address',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: gstController,
                  label: 'GST Number (Optional)',
                  icon: Icons.receipt_long,
                  hint: 'Enter GST number',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                        if (mounted) {
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
                              behavior: SnackBarBehavior.floating,
                            ),
                        );
                      }
                      return;
                      }

                      try {
                        // Update customer in database
                        final updatedCustomer = customer.copyWith(
                          name: nameController.text.trim(),
                          phone: phoneController.text.trim(),
                          gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                        );

                        // Update in local database
                        await SQLiteHelper().updateCustomerData(updatedCustomer.toMap());
                        
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Customer updated successfully',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                        );
                        _loadCustomers();
                      }
                    } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Error updating customer: $e',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Customer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Add search functionality
    filteredCustomers = customers.where((customer) {
      final lowerQuery = _searchController.text.toLowerCase();
      return customer.name.toLowerCase().contains(lowerQuery) ||
             customer.phone.toLowerCase().contains(lowerQuery) ||
             (customer.gstNo?.toLowerCase().contains(lowerQuery) ?? false) ||
             (customer.address?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        elevation: 1,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          splashRadius: 20,
        ),
        actions: [
          // IconButton(
          //   icon: Icon(Icons.file_download, color: Colors.grey[700]),
          //   onPressed: isImporting ? null : _importCustomersFromExcel,
          //   tooltip: 'Import from Excel',
          // ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.grey[700]),
            onPressed: _showExcelFormatHelp,
            tooltip: 'Excel format help',
          ),
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
                    blurRadius: 8,
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
          ? Container(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
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
              ),
            )
          : customers.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.people_alt_outlined,
                            size: 80,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'No Customers Yet',
                          style: TextStyle(
                            fontSize: 22,
                            fontFamily: 'tabfont',
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first customer to get started',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'fontmain',
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Enhanced Stats Card
                    Container(
                      margin: const EdgeInsets.all(16),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.people,
                                      color: primaryColor,
                                      size: 32,
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
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_off,
                                      color: Colors.orange,
                                      size: 32,
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
                                      'Pending Sync',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'fontmain',
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search customers...',
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.transparent),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),

                    // Enhanced Customer List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: customer.isUploaded
                                          ? primaryColor.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      customer.isUploaded ? Icons.cloud_done : Icons.cloud_upload,
                                      color: customer.isUploaded ? primaryColor : Colors.orange,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontFamily: 'tabfont',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                customer.phone,
                                                style: const TextStyle(
                                                  fontFamily: 'fontmain',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (customer.gstNo != null && customer.gstNo!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.receipt_long,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'GST: ${customer.gstNo == '' ? 'N/A' : customer.gstNo ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    fontFamily: 'fontmain',
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                customer.address == '' ? 'N/A' : customer.address??'N/A',
                                                style: const TextStyle(
                                                  fontFamily: 'fontmain',
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: Colors.grey[500],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateFormat.format(customer.createdAt),
                                              style: TextStyle(
                                                fontFamily: 'fontmain',
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                    color: Colors.white,
                                    padding: EdgeInsets.zero,
                                    onSelected: (String value) {
                                      if (value == 'edit') {
                                        _showEditCustomerBottomSheet(customer);
                                      } else if (value == 'delete') {
                                        _deleteCustomer(customer);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
            heroTag: "importExcel",
            onPressed: isImporting ? null : _importCustomersFromExcel,
            backgroundColor: Colors.deepPurple,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.file_download, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "addCustomer",
            onPressed: _showAddCustomerDialog,
            backgroundColor: primaryColor,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_add, color: Colors.white, size: 28),
          ),
          if (notUploadedCustomers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                heroTag: "syncCustomers",
                onPressed: isUploading ? null : _uploadToFirebase,
                backgroundColor: primaryColor,
                elevation: 0,
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
            ),
          ],
        ],
      ),
    );
  }
}
