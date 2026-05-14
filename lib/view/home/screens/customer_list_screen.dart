import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart' as excel;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/services/customer_service.dart';

import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';

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
    _searchController.addListener(_filterCustomers);
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);

    try {
      // 1. Fetch from API
      final apiCustomers = await CustomerService().getCustomers();

      // 2. Load local SQLite customers
      final rawLocalData = await SQLiteHelper().getAllCustomers();
      final localCustomers = rawLocalData.map((map) => CustomerModel.fromMap(map)).toList();

      // Index API customers by phone
      final apiMap = {for (var c in apiCustomers) c.phoneNumber: c};
      final List<CustomerModel> mergedList = [];
      final List<CustomerModel> pendingSync = [];

      // Merge local and API
      for (final local in localCustomers) {
        if (apiMap.containsKey(local.phoneNumber)) {
          mergedList.add(apiMap[local.phoneNumber]!.copyWith(isUploaded: true));
        } else {
          mergedList.add(local.copyWith(isUploaded: false));
          pendingSync.add(local);
        }
      }

      // Add API-only customers
      for (final api in apiCustomers) {
        if (!mergedList.any((c) => c.phoneNumber == api.phoneNumber)) {
          mergedList.add(api.copyWith(isUploaded: true));
        }
      }

      if (!mounted) return;

      setState(() {
        customers = mergedList;
        _filterCustomers(); // This updates filteredCustomers
        notUploadedCustomers = pendingSync;
        isLoading = false;
      });
    } catch (e) {
        SnackBarUtils.showError(context, 'Error loading customers: $e');
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
            MyText(
              text: 'Import Customers',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: const MyText(
          text: 'Need help with Excel format? View detailed instructions first.',
          fontSize: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const MyText(text: 'Skip Help'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: const MyText(
              text: 'Show Help',
              color: Colors.white,
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
                  MyText(
                    text: 'Importing customers...',
                    fontSize: 16,
                    fontFamily: 'fontmain',
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  MyText(
                    text: 'Processing ${file.name}',
                    fontSize: 14,
                    fontFamily: 'fontmain',
                    color: Colors.grey[500],
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
              errors.add('Row ${i + 1}: Invalid phone number format ($phone)');
              failedImports++;
              continue;
            }

            // Check for duplicates
            if (customers.any((customer) => customer.phone == phone)) {
              errors.add('Row ${i + 1}: Duplicate phone number found ($phone)');
              failedImports++;
              continue;
            }

            // Create customer model
            CustomerModel customer = CustomerModel(
              name: name,
              phoneNumber: phone,
              address: address.isEmpty ? null : address,
              gstNo: gstNo.isEmpty ? null : gstNo,
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
                MyText(
                  text: successfulImports > 0 ? 'Import Complete' : 'Import Failed',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(text: resultMessage),
                  if (successfulImports > 0) const SizedBox(height: 16),
                  if (successfulImports > 0)
                    MyText(
                      text: 'Would you like to sync the imported customers to the cloud?',
                      fontSize: 14,
                      color: Colors.grey[700],
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
                child: const MyText(
                  text: 'Close',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
                  child: const MyText(
                    text: 'Sync Now',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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

        SnackBarUtils.showError(context, 'Error importing customers: $e');
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
    // Firebase Storage removed. Sample data is embedded in the app.
    debugPrint('downloadExcelFromFirebase: Firebase Storage not available');
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
            MyText(
              text: 'Download Sample Data',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'This will download a sample Excel template to your device.',
              fontSize: 16,
            ),
            SizedBox(height: 12),
            MyText(
              text: 'After download, you can select this file when importing customers.',
              fontSize: 14,
              color: Colors.grey,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const MyText(text: 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: const MyText(
              text: 'Download',
              color: Colors.white,
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
                const MyText(
                  text: 'Downloading sample data...',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 8),
                const MyText(
                  text: 'Please wait',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );

      // 1. Check and Request Permissions
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.storage.status;

        if (status.isDenied || status.isRestricted) {
          status = await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          if (mounted) {
            Navigator.pop(context); // Close progress dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const MyText(text: 'Permission Required'),
                content: const MyText(
                    text: 'Storage permission is required to save the file. Please enable it in settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const MyText(text: 'Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: const MyText(text: 'Open Settings'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        if (!status.isGranted) {
            SnackBarUtils.showError(context, 'Storage permission denied');
          return;
        }
      }

      // 2. Download via http from a public URL (Firebase Storage removed)
      const url = ''; // No sample download URL configured
      if (url.isEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) {
          SnackBarUtils.showWarning(context, 'Sample download not available. Please create your own Excel template.');
        }
        return;
      }

      // 3. Fetch the file data using http
      final response = await http.get(Uri.parse(url));

      // Close progress dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (response.statusCode == 200) {
        // 4. Get the local storage path
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          // Ensure the directory exists or fall back
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else {
          downloadsDir = await getApplicationDocumentsDirectory();
        }

        if (downloadsDir == null) {
          if (mounted) {
            SnackBarUtils.showError(context, 'Could not access storage directory');
          }
          return;
        }

        String fullPath = "${downloadsDir.path}/Sample_Customer_Data.xlsx";
        File file = File(fullPath);

        // 4. Write the bytes to the file
        await file.writeAsBytes(response.bodyBytes);

        // Show success message with file name
        final fileName = fullPath.split('/').last;
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Downloaded: $fileName\nYou can now select this file for import');
        }
      } else {
        if (mounted) {
          SnackBarUtils.showError(context, 'Download failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

        if (mounted) {
          SnackBarUtils.showError(context, 'Download error: $e');
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
            MyText(
              text: 'Excel Format Guide',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(
                text: 'Your Excel file should have the following column structure:',
                fontWeight: FontWeight.bold,
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
                    const MyText(text: 'Column A: Customer Name (Required)', fontWeight: FontWeight.w500),
                    const MyText(text: 'Column B: Phone Number (Required)', fontWeight: FontWeight.w500),
                    const MyText(text: 'Column C: Address (Optional)', fontWeight: FontWeight.w500),
                    const MyText(text: 'Column D: GST Number (Optional)', fontWeight: FontWeight.w500),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const MyText(
                text: 'Example:',
                fontWeight: FontWeight.bold,
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
                    const MyText(text: 'John Doe | 9876543210 | 123 Main St | GST123ABC'),
                    const MyText(text: 'Jane Smith | 9876543211 | 456 Oak Ave | '),
                    const MyText(text: 'Bob Johnson | 9876543212 | 789 Pine Rd | GST456DEF'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const MyText(
                text: 'Note: Make sure to remove any extra columns or rows before uploading.',
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const MyText(
                text:
                    'Note: If you have no data then download a sample data by clicking on the "Download Sample" button.',
                color: Colors.grey,
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
            child: const MyText(
              text: 'Download Sample',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
            child: const MyText(
              text: 'OK',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadToFirebase() async {
    if (notUploadedCustomers.isEmpty) {
      SnackBarUtils.showWarning(context, 'No customers to upload');
      return;
    }

    setState(() => isUploading = true);

    try {
      final service = CustomerService();
      int successCount = 0;

      for (var customer in notUploadedCustomers) {
        try {
          await service.createCustomer(
            name: customer.name,
            phoneNumber: customer.phoneNumber,
            address: customer.address,
            gstNo: customer.gstNo,
          );
          successCount++;
        } catch (e) {
          debugPrint('Error uploading customer ${customer.name}: $e');
        }
      }

      setState(() => isUploading = false);

        SnackBarUtils.showSuccess(context, 'Successfully uploaded $successCount customers');
        _loadCustomers();
    } catch (e) {
      setState(() => isUploading = false);
        SnackBarUtils.showError(context, 'Error uploading: $e');
    }
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredCustomers = customers.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query) ||
            (customer.gstNo?.toLowerCase().contains(query) ?? false) ||
            (customer.address?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> deleteCustomerFromFirebase(String phone) async {
    // Firebase removed - delete via API instead (if needed)
    try {
      await CustomerService().deleteCustomer(phone);
    } catch (e) {
      debugPrint('deleteCustomerFromFirebase: $e');
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
            MyText(
              text: 'Delete Customer',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MyText(
            text: 'Are you sure you want to delete ${customer.name}? This action cannot be undone.',
            fontSize: 16,
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
            child: const MyText(
              text: 'Cancel',
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
            child: const MyText(
              text: 'Delete',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1️⃣ Delete from API if uploaded
        if (customer.isUploaded && customer.id != null) {
          await CustomerService().deleteCustomer(customer.id!);
        }

        // 2️⃣ Delete from SQLite
        await SQLiteHelper().deleteCustomerData(customer.phoneNumber);

        // 3️⃣ Update UI instantly
        setState(() {
          customers.removeWhere((c) => c.phoneNumber == customer.phoneNumber);
          _filterCustomers();
          notUploadedCustomers.removeWhere((c) => c.phoneNumber == customer.phoneNumber);
        });

        SnackBarUtils.showSuccess(context, 'Customer deleted successfully');
      } catch (e) {
        SnackBarUtils.showError(context, 'Delete failed: $e');
      }
    }
  }

  Future<void> _showCustomerBottomSheet({CustomerModel? customer}) async {
    final bool isEdit = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phoneNumber ?? ''); // Assuming backwards compatible
    final gstController = TextEditingController(text: customer?.gstNo ?? '');
    final addressController = TextEditingController(text: customer?.address ?? '');

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
                // Change title dynamically
                MyText(
                  text: isEdit ? 'Edit Customer' : 'Add Customer',
                  fontSize: 24,
                  color: Colors.white,
                 
                  fontWeight: FontWeight.bold,
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
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
                        SnackBarUtils.showWarning(context, 'Please fill in required fields');
                        return;
                      }

                      try {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );

                        if (isEdit) {
                          // Edit existing customer
                          CustomerModel? updatedFromApi;
                          if (customer.id != null) {
                            try {
                              updatedFromApi = await CustomerService().updateCustomer(
                                id: customer.id!,
                                name: nameController.text.trim(),
                                phoneNumber: phoneController.text.trim(),
                                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                                gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                              );
                            } catch (e) {
                              debugPrint('API update failed: $e');
                            }
                          }

                          final updatedCustomer = (updatedFromApi ?? customer).copyWith(
                            name: nameController.text.trim(),
                            phoneNumber: phoneController.text.trim(),
                            gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                            address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                          );

                          // Depending on your sync model, might need local sqlite updates
                          // await SQLiteHelper().updateCustomerData(updatedCustomer.toMap(), updatedCustomer.phoneNumber);

                          Navigator.pop(context); // Close loading dialog
                          Navigator.pop(context); // Close bottom sheet
                          SnackBarUtils.showSuccess(context, 'Customer updated successfully');
                        } else {
                          // Add new customer
                          CustomerModel? newCustomer;
                          try {
                            newCustomer = await CustomerService().createCustomer(
                              name: nameController.text.trim(),
                              phoneNumber: phoneController.text.trim(),
                              address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                              gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                            );
                          } catch (e) {
                            debugPrint('API creation failed, saving locally: $e');
                          }

                          final customerToSave = newCustomer ??
                              CustomerModel(
                                name: nameController.text.trim(),
                                phoneNumber: phoneController.text.trim(),
                                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                                gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                                isUploaded: false,
                              );

                          await SQLiteHelper().saveCustomerData(customerToSave.toMap());
                          Navigator.pop(context); // Close loading dialog
                          Navigator.pop(context); // Close bottom sheet
                          SnackBarUtils.showSuccess(context, 'Customer added successfully');
                        }

                        _loadCustomers();
                      } catch (e) {
                        Navigator.pop(context); // Close loading dialog
                        SnackBarUtils.showError(context, isEdit ? 'Error updating customer: $e' : 'Error adding customer: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: MyText(
                      text: isEdit ? 'Update Customer' : 'Add Customer',
                     
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                    child: const MyText(
                      text: 'Cancel',
                      fontFamily: 'fontmain',
                      fontSize: 16,
                      color: Colors.grey,
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
    List<TextInputFormatter>? inputFormatters,
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
        inputFormatters: inputFormatters,
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
    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, _) {
        if (!subProvider.hasPermission("MyCustomers", checkView: true)) {
          return Scaffold(
            appBar: AppBar(
              title: const MyText(text: 'Customers'),
              backgroundColor: primaryColor,
            ),
            body: const AccessDeniedWidget(feature: "MyCustomers"),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50], // Very clean background
          appBar: AppBar(
            title: const MyText(
              text: 'Customers',
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.black87,
            ),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black87),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _showExcelFormatHelp,
                tooltip: 'Excel format help',
              ),
              if (subProvider.hasPermission("MyCustomers", checkCreate: true))
                IconButton(
                  icon: isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_download_outlined),
                  onPressed: isImporting ? null : _importCustomersFromExcel,
                  tooltip: 'Import from Excel',
                ),
              if (notUploadedCustomers.isNotEmpty && subProvider.hasPermission("MyCustomers", checkCreate: true))
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : _uploadToFirebase,
                    icon: isUploading
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload, size: 18, color: Colors.white),
                    label: MyText(
                      text: 'Sync (${notUploadedCustomers.length})',
                      color: Colors.white,
                      fontFamily: 'fontmain',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ),
          body: isLoading
              ? _buildLoadingState()
              : customers.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildStatsRow(),
                        _buildSearchBar(),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              return _buildCustomerItem(filteredCustomers[index], subProvider);
                            },
                          ),
                        ),
                      ],
                    ),
          floatingActionButton: subProvider.hasPermission("MyCustomers", checkCreate: true)
              ? FloatingActionButton.extended(
                  heroTag: "addBtn",
                  onPressed: () => _showCustomerBottomSheet(),
                  backgroundColor: primaryColor,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  label: const MyText(
                    text: 'Add Customer',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          MyText(
            text: 'No Customers Found',
            fontSize: 18,
           
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          MyText(
            text: 'Add your first customer to get started',
            fontSize: 14,
            fontFamily: 'fontmain',
            color: Colors.grey[500],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Total Customers', customers.length.toString(), Icons.people, primaryColor)),
          const SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(
                  'Pending Sync', notUploadedCustomers.length.toString(), Icons.cloud_off, Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              MyText(
                text: count,
                fontSize: 20,
               
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          MyText(
            text: title,
            fontSize: 13,
            fontFamily: 'fontmain',
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontFamily: 'fontmain', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search customers...',
            hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'fontmain'),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _filterCustomers();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerItem(CustomerModel customer, SubscriptionProvider subProvider) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (subProvider.hasPermission("MyCustomers", checkEdit: true)) {
            _showCustomerBottomSheet(customer: customer);
          } else {
             SnackBarUtils.showWarning(context, "No Edit Permission under current plan");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: MyText(
                  text: customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?',
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: customer.name,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        if (customer.isUploaded)
                          const Icon(Icons.cloud_done, color: primaryColor, size: 16)
                        else
                          const Icon(Icons.cloud_upload, color: Colors.orange, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        MyText(
                          text: customer.phoneNumber,
                          fontFamily: 'fontmain',
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                    if (customer.gstNo != null && customer.gstNo!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.receipt_long, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          MyText(
                            text: 'GST: ${customer.gstNo}',
                            fontFamily: 'fontmain',
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ],
                      ),
                    ],
                    if (customer.address != null && customer.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: MyText(
                              text: customer.address!,
                              fontFamily: 'fontmain',
                              fontSize: 13,
                              color: Colors.grey[700],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    MyText(
                      text: 'Added: ${dateFormat.format(customer.createdAt ?? DateTime.now())}',
                      fontFamily: 'fontmain',
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (value) {
                  if (value == 'edit') {
                    if (subProvider.hasPermission("MyCustomers", checkEdit: true)) {
                      _showCustomerBottomSheet(customer: customer);
                    } else {
                       SnackBarUtils.showWarning(context, "No Edit Permission under current plan");
                    }
                  }
                  if (value == 'delete') {
                    if (subProvider.hasPermission("MyCustomers", checkDelete: true)) {
                      _deleteCustomer(customer);
                    } else {
                       SnackBarUtils.showWarning(context, "No Delete Permission under current plan");
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        MyText(text: 'Edit', fontFamily: 'fontmain'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        MyText(text: 'Delete', fontFamily: 'fontmain', color: Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
