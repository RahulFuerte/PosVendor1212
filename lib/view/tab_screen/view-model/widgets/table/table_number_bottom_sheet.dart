// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/core/utils/snackbar_utils.dart';

// Package imports:
import 'package:community_material_icon/community_material_icon.dart';

class TableNumberBottomSheet {
  /// Shows a bottom sheet to collect table number for dine-in orders
  ///
  /// Parameters:
  /// - [context]: BuildContext for the bottom sheet
  /// - [title]: Title text (default: 'Dine-In Order')
  /// - [labelText]: Input field label (default: 'Table Number')
  /// - [hintText]: Input field hint (default: 'Enter table number')
  /// - [primaryColor]: Primary color for buttons and borders
  /// - [onConfirm]: Callback when user confirms with table number
  /// - [icon]: Custom icon (default: table chair icon)
  /// - [confirmButtonText]: Text for confirm button (default: 'Confirm')
  /// - [cancelButtonText]: Text for cancel button (default: 'Cancel')
  static Future<String?> show({
    required BuildContext context,
    String title = 'Dine-In Order',
    String labelText = 'Table Number',
    String hintText = 'Enter table number',
    Color? primaryColor,
    IconData? icon,
    String confirmButtonText = 'Confirm',
    String cancelButtonText = 'Cancel',
    String? initialValue,
    TextInputType keyboardType = TextInputType.number,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final Color effectivePrimaryColor = primaryColor ?? Theme.of(context).primaryColor;
    final IconData effectiveIcon = icon ?? CommunityMaterialIcons.table_chair;

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon and Title
              Row(
                children: [
                  Icon(
                    effectiveIcon,
                    color: effectivePrimaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  MyText(
                    text: title,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Input Field
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: labelText,
                  hintText: hintText,
                  prefixIcon: Icon(CommunityMaterialIcons.numeric, color: effectivePrimaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: effectivePrimaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: MyText(
                        text: cancelButtonText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.text.trim().isEmpty) {
                          SnackBarUtils.showWarning(sheetContext, 'Please enter $labelText');
                          return;
                        }
                        Navigator.pop(sheetContext, controller.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectivePrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: MyText(
                        text: confirmButtonText,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// Generic reusable bottom sheet for any input
class CustomInputBottomSheet {
  /// Shows a customizable bottom sheet for collecting user input
  static Future<String?> show({
    required BuildContext context,
    required String title,
    required String labelText,
    String? hintText,
    Color? primaryColor,
    IconData? icon,
    String confirmButtonText = 'Confirm',
    String cancelButtonText = 'Cancel',
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    Widget? subtitle,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final Color effectivePrimaryColor = primaryColor ?? Theme.of(context).primaryColor;

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon and Title
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: effectivePrimaryColor, size: 28),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: MyText(
                      text: title,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (subtitle != null) ...[
                const SizedBox(height: 8),
                subtitle,
              ],

              const SizedBox(height: 20),

              // Input Field
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                autofocus: true,
                maxLines: maxLines,
                maxLength: maxLength,
                decoration: InputDecoration(
                  labelText: labelText,
                  hintText: hintText ?? 'Enter $labelText',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: effectivePrimaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: MyText(
                        text: cancelButtonText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final value = controller.text.trim();
                        if (validator != null) {
                          final error = validator(value);
                          if (error != null) {
                            SnackBarUtils.showWarning(sheetContext, error);
                            return;
                          }
                        } else if (value.isEmpty) {
                          SnackBarUtils.showWarning(sheetContext, 'Please enter $labelText');
                          return;
                        }
                        Navigator.pop(sheetContext, value);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectivePrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: MyText(
                        text: confirmButtonText,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

/* 
USAGE EXAMPLES:

// Example 1: Simple table number input
final tableNumber = await TableNumberBottomSheet.show(
  context: context,
  primaryColor: appbar1,
);

if (tableNumber != null) {
}

// Example 2: Custom styling
final roomNumber = await TableNumberBottomSheet.show(
  context: context,
  title: 'Room Service',
  labelText: 'Room Number',
  hintText: 'Enter room number',
  primaryColor: Colors.blue,
  icon: Icons.hotel,
  confirmButtonText: 'Proceed',
);

// Example 3: Generic input for customer name
final customerName = await CustomInputBottomSheet.show(
  context: context,
  title: 'Customer Details',
  labelText: 'Customer Name',
  hintText: 'Enter customer name',
  primaryColor: appbar1,
  icon: Icons.person,
  keyboardType: TextInputType.name,
);

// Example 4: Multi-line notes input
final notes = await CustomInputBottomSheet.show(
  context: context,
  title: 'Special Instructions',
  labelText: 'Notes',
  hintText: 'Add any special instructions',
  primaryColor: appbar1,
  icon: Icons.note,
  keyboardType: TextInputType.multiline,
  maxLines: 4,
  maxLength: 200,
);

// Example 5: With custom validation
final phoneNumber = await CustomInputBottomSheet.show(
  context: context,
  title: 'Contact Information',
  labelText: 'Phone Number',
  hintText: 'Enter phone number',
  primaryColor: appbar1,
  icon: Icons.phone,
  keyboardType: TextInputType.phone,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
  },
);

// Example 6: In your existing function
Future _showTableNumberBottomSheet(BuildContext parentContext) async {
  final printprovider = Provider.of(parentContext, listen: false);
  
  final tableNumber = await TableNumberBottomSheet.show(
    context: parentContext,
    primaryColor: appbar1,
    confirmButtonText: 'Print Receipt',
  );

  if (tableNumber == null) return; // User cancelled

  // Show loading dialog
  showDialog(
    context: parentContext,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    // Fetch shop data
    final doc = await FirebaseFirestore.instance
        .collection('AllAdmins')
        .doc(adminUid)
        .collection('customer')
        .doc(widget.phoneNo)
        .get();

    String shopName = 'N/A';
    String contact = 'N/A';
    String address = 'N/A';

    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        shopName = data['shopName'] ?? 'N/A';
        contact = data['contact'] ?? 'N/A';
        address = data['address'] ?? 'N/A';
      }
    }

    if (parentContext.mounted) {
      Navigator.pop(parentContext); // Close loading dialog
    }

    // Print receipt
    await DirectPrintHelper.printDineInReceipt(
      adminUid: widget.phoneNo,
      context: parentContext,
      printer: printprovider.selectedPrinter!,
      paperSize: printprovider.selectedPaperSize,
      items: selectedItemsDetails,
      total: subtotal,
      shopName: shopName,
      contact: contact,
      address: address,
      tableNumber: tableNumber,
    );

    printprovider.clearCart();
  } catch (e) {
    if (parentContext.mounted) {
      Navigator.pop(parentContext);
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Printing failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
*/
