import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/view/home/reports/widgets/report_skeleton.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart' as excel;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/services/customer_service.dart';

import 'package:pos/data/models/customer_model.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({Key? key}) : super(key: key);

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  String phoneNo = '';
  String adminUid = '';

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
    _loadSessionData();
    _searchController.addListener(_filterCustomers);
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
    });
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);

    try {
      // Fetch from API
      final apiCustomers = await CustomerService().getCustomers();

      // All customers come from the API in online-only mode
      final List<CustomerModel> mergedList = apiCustomers.map((c) => c.copyWith(isUploaded: true)).toList();

      if (!mounted) return;

      setState(() {
        customers = mergedList;
        _filterCustomers(); // This updates filteredCustomers
        notUploadedCustomers = [];
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
        title:  Row(
          children: [
            const Icon(Icons.info, color: Colors.blue),
            const SizedBox(width: 12),
            MyText(
              text: AppLocale.importCustomers.getString(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: MyText(text: AppLocale.needHelpWithExcelFormat.getString(context),
          fontSize: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: MyText(text: AppLocale.skipHelp.getString(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: MyText(text: AppLocale.showHelp.getString(context),
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
                    text: AppLocale.importingCustomers.getString(context),
                    fontSize: 16,
                    fontFamily: 'Outfit',
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  MyText(
                    text: '${AppLocale.processingFile.getString(context)}${file.name}',
                    fontSize: 14,
                    fontFamily: 'Outfit',
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
                errors.add(AppLocale.invalidExcelFormatNamePhone.getString(context));
                throw Exception('Invalid Excel format: ${errors.join(', ')}');
              }
              continue;
            }

            // Check if row has enough columns
            if (row.length < 2) {
              errors.add('Row ${i + 1}${AppLocale.insufficientDataNamePhone.getString(context)}');
              failedImports++;
              continue;
            }

            // Extract data from columns (assuming A, B, C, D are name, phone, address, GST)
            String name = row[0]?.value?.toString().trim() ?? '';
            String phone = row[1]?.value?.toString().trim() ?? '';
            String address = row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '';
            String gstNo = row.length > 3 ? (row[3]?.value?.toString().trim() ?? '') : '';

            // Validate required fields
            if (name.isEmpty || phone.isEmpty) {
              errors.add('Row ${i + 1}${AppLocale.nameAndPhoneRequired.getString(context)}');
              failedImports++;
              continue;
            }

            // Validate phone number format (basic validation)
            if (!_isValidPhoneNumber(phone)) {
              errors.add('Row ${i + 1}${AppLocale.invalidPhoneNumberFormat.getString(context)}$phone)');
              failedImports++;
              continue;
            }

            // Check for duplicates
            if (customers.any((customer) => customer.phone == phone)) {
              errors.add('Row ${i + 1}${AppLocale.duplicatePhoneNumberFound.getString(context)}$phone)');
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
        String resultMessage = '${AppLocale.importCompleted.getString(context)}$successfulImports${AppLocale.importFailedMsg.getString(context)}$failedImports';
        if (errors.isNotEmpty) {
          resultMessage += '${AppLocale.errorsList.getString(context)}${errors.take(3).join('\n')}';
          if (errors.length > 3) {
            resultMessage += '${AppLocale.andMore.getString(context)}${errors.length - 3}${AppLocale.more.getString(context)}';
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
                  text: successfulImports > 0 ? AppLocale.importComplete.getString(context) : AppLocale.importFailed.getString(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(text: resultMessage),
                  if (successfulImports > 0) const SizedBox(height: 16),
                  if (successfulImports > 0)
                    MyText(
                      text: AppLocale.syncImportedCustomers.getString(context),
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
                child: MyText(
                  text: AppLocale.close.getString(context),
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
                  child: MyText(text: AppLocale.syncNow.getString(context),
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
        title:  Row(
          children: [
            const Icon(Icons.download, color: Colors.blue),
            const SizedBox(width: 12),
            MyText(
              text: AppLocale.downloadSampleData.getString(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MyText(
              text: AppLocale.downloadSampleDataDesc.getString(context),
              fontSize: 16,
            ),
            const SizedBox(height: 12),
            MyText(
              text: AppLocale.downloadSampleDataDesc2.getString(context),
              fontSize: 14,
              color: Colors.grey,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: MyText(text: AppLocale.cancel.getString(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: MyText(text: AppLocale.download.getString(context),
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
            child:  Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
                const SizedBox(height: 24),
                MyText(
                  text: AppLocale.downloadingSampleData.getString(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                const SizedBox(height: 8),
                MyText(
                  text: AppLocale.pleaseWait.getString(context),
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
                title: MyText(text: AppLocale.permissionRequired.getString(context)),
                content: MyText(text: AppLocale.storagePermissionRequired.getString(context)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: MyText(text: AppLocale.cancel.getString(context)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: MyText(text: AppLocale.openSettings.getString(context)),
                  ),
                ],
              ),
            );
          }
          return;
        }

        if (!status.isGranted) {
          SnackBarUtils.showError(context, AppLocale.storagePermissionDenied.getString(context));
          return;
        }
      }

      // 2. Download via http from a public URL (Firebase Storage removed)
      const url = ''; // No sample download URL configured
      if (url.isEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) {
          SnackBarUtils.showWarning(context, AppLocale.sampleDownloadNotAvailable.getString(context));
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
            SnackBarUtils.showError(context, AppLocale.couldNotAccessStorage.getString(context));
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
          SnackBarUtils.showSuccess(context, '${AppLocale.downloadedMsg.getString(context)}$fileName${AppLocale.downloadedMsg2.getString(context)}');
        }
      } else {
        if (mounted) {
          SnackBarUtils.showError(context, '${AppLocale.downloadFailed.getString(context)}${response.statusCode}');
        }
      }
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        SnackBarUtils.showError(context, '${AppLocale.downloadError.getString(context)}$e');
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
        title:  Row(
          children: [
            const Icon(Icons.info, color: Colors.blue),
            const SizedBox(width: 12),
            MyText(
              text: AppLocale.excelFormatGuide.getString(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(text: AppLocale.excelColumnStructure.getString(context),
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child:  Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(text: AppLocale.columnA.getString(context), fontWeight: FontWeight.w500),
                    MyText(text: AppLocale.columnB.getString(context), fontWeight: FontWeight.w500),
                    MyText(text: AppLocale.columnC.getString(context), fontWeight: FontWeight.w500),
                    MyText(text: AppLocale.columnD.getString(context), fontWeight: FontWeight.w500),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MyText(text: AppLocale.example.getString(context),
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
                    MyText(text: 'John Doe | 9876543210 | 123 Main St | GST123ABC'),
                    MyText(text: 'Jane Smith | 9876543211 | 456 Oak Ave | '),
                    MyText(text: 'Bob Johnson | 9876543212 | 789 Pine Rd | GST456DEF'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MyText(text: AppLocale.removeExtraColumnsRows.getString(context),
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              MyText(text: AppLocale.noDataDownloadSample.getString(context),
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
            child: MyText(text: AppLocale.downloadSample.getString(context),
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
            child: MyText(
              text: AppLocale.ok.getString(context),
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
      SnackBarUtils.showWarning(context, AppLocale.noCustomersToUpload.getString(context));
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

      SnackBarUtils.showSuccess(context, '${AppLocale.successfullyUploaded.getString(context)}$successCount${AppLocale.customersMsg.getString(context)}');
      _loadCustomers();
    } catch (e) {
      setState(() => isUploading = false);
      SnackBarUtils.showError(context, '${AppLocale.errorUploading.getString(context)}$e');
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
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            MyText(
              text: AppLocale.deleteCustomer.getString(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: MyText(
            text: AppLocale.areYouSureDeleteCustomer.getString(context),
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
            child: MyText(
              text: AppLocale.cancel.getString(context),
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
            child: MyText(
              text: AppLocale.delete.getString(context),
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

        // 3️⃣ Update UI instantly
        setState(() {
          customers.removeWhere((c) => c.phoneNumber == customer.phoneNumber);
          _filterCustomers();
          notUploadedCustomers.removeWhere((c) => c.phoneNumber == customer.phoneNumber);
        });

       context.mounted? SnackBarUtils.showSuccess(context, AppLocale.customerDeletedSuccessfully.getString(context)):null;
      } catch (e) {
        SnackBarUtils.showError(context, '${AppLocale.deleteFailed.getString(context)}$e');
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
                  text: isEdit
                      ? AppLocale.editCustomerTitle.getString(context)
                      : AppLocale.addCustomer.getString(context),
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 24),
                _buildInputField(
                  controller: nameController,
                  label: '${AppLocale.customerName.getString(context)} *',
                  icon: Icons.person,
                  hint: AppLocale.enterCustomerName.getString(context),
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: phoneController,
                  label: '${AppLocale.mobileNumber.getString(context)} *',
                  icon: Icons.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  hint: AppLocale.enterPhoneNumber.getString(context),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: addressController,
                  label: AppLocale.customerAddressLabel.getString(context),
                  icon: Icons.home,
                  hint: AppLocale.enterCustomerAddress.getString(context),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: gstController,
                  label: AppLocale.gstNumberOptional.getString(context),
                  icon: Icons.receipt_long,
                  hint: AppLocale.enterGstNumber.getString(context),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                        SnackBarUtils.showWarning(context, AppLocale.pleaseFillRequiredFields.getString(context));
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
                          if (customer.id != null) {
                            try {
                              await CustomerService().updateCustomer(
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

                          // Depending on your sync model, might need local sqlite updates

                          Navigator.pop(context); // Close loading dialog
                          Navigator.pop(context); // Close bottom sheet
                          SnackBarUtils.showSuccess(context, AppLocale.customerUpdatedSuccessfully.getString(context));
                        } else {
                          // Add new customer
                          try {
                            await CustomerService().createCustomer(
                              name: nameController.text.trim(),
                              phoneNumber: phoneController.text.trim(),
                              address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                              gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                            );
                          } catch (e) {
                            debugPrint('API creation failed, saving locally: $e');
                          }

                          Navigator.pop(context); // Close loading dialog
                          Navigator.pop(context); // Close bottom sheet
                          SnackBarUtils.showSuccess(context, AppLocale.customerAddedSuccessfully.getString(context));
                        }

                        _loadCustomers();
                      } catch (e) {
                        Navigator.pop(context); // Close loading dialog
                        SnackBarUtils.showError(
                            context, isEdit ? '${AppLocale.errorUpdatingCustomer.getString(context)}$e' : '${AppLocale.errorAddingCustomer.getString(context)}$e');
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
                      text: isEdit
                          ? AppLocale.updateCustomer.getString(context)
                          : AppLocale.addCustomer.getString(context),
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
                    child: MyText(
                      text: AppLocale.cancel.getString(context),
                      fontFamily: 'Outfit',
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
              title: MyText(text: AppLocale.customers.getString(context)),
              backgroundColor: primaryColor,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: const AccessDeniedWidget(feature: "MyCustomers"),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50], // Very clean background
          appBar: AppBar(
            title: MyText(
              text: AppLocale.customers.getString(context),
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.black87,
            ),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
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
                tooltip: AppLocale.excelFormatHelp.getString(context),
              ),
              if (subProvider.hasPermission("MyCustomers", checkCreate: true))
                IconButton(
                  icon: isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_download_outlined),
                  onPressed: isImporting ? null : _importCustomersFromExcel,
                  tooltip: AppLocale.importFromExcel.getString(context),
                ),
              if (notUploadedCustomers.isNotEmpty && subProvider.hasPermission("MyCustomers", checkCreate: true))
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : _uploadToFirebase,
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload, size: 18, color: Colors.white),
                    label: MyText(
                      text: '${AppLocale.syncLabel.getString(context)} (${notUploadedCustomers.length})',
                      color: Colors.white,
                      fontFamily: 'Outfit',
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
                  label: MyText(
                    text: AppLocale.addCustomer.getString(context),
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
    return const SingleChildScrollView(
      child: Column(
        children: [
          ReportSkeleton(height: 80, itemCount: 1, padding: EdgeInsets.all(16)), // For stats row
          ReportSkeleton(height: 120, itemCount: 5), // For customer items
        ],
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
            text: AppLocale.noCustomersFound.getString(context),
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          MyText(
            text: AppLocale.addFirstCustomerMsg.getString(context),
            fontSize: 14,
            fontFamily: 'Outfit',
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
          Expanded(
              child: _buildStatCard(
                  AppLocale.totalCustomers.getString(context), customers.length.toString(), Icons.people, primaryColor)),
          const SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(AppLocale.pendingSync.getString(context),
                  notUploadedCustomers.length.toString(), Icons.cloud_off, Colors.orange)),
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
            fontFamily: 'Outfit',
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
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
          decoration: InputDecoration(
            hintText: AppLocale.searchCustomers.getString(context),
            hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Outfit'),
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
            SnackBarUtils.showWarning(context, AppLocale.noEditPermissionMsg.getString(context));
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
                          fontFamily: 'Outfit',
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
                            text: '${AppLocale.gstPrefix.getString(context)}${customer.gstNo}',
                            fontFamily: 'Outfit',
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
                              fontFamily: 'Outfit',
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
                      text: '${AppLocale.addedPrefix.getString(context)}${dateFormat.format(customer.createdAt ?? DateTime.now())}',
                      fontFamily: 'Outfit',
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
                      SnackBarUtils.showWarning(context, AppLocale.noEditPermissionMsg.getString(context));
                    }
                  }
                  if (value == 'delete') {
                    if (subProvider.hasPermission("MyCustomers", checkDelete: true)) {
                      _deleteCustomer(customer);
                    } else {
                      SnackBarUtils.showWarning(context, AppLocale.noDeletePermissionMsg.getString(context));
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        MyText(text: AppLocale.edit.getString(context), fontFamily: 'Outfit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        MyText(text: AppLocale.delete.getString(context), fontFamily: 'Outfit', color: Colors.red),
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
