// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Future<void> showSaveOrderBottomSheet({
//   required BuildContext context,
//   required GlobalKey<FormState> formKey,
//   required TextEditingController nameController,
//   required TextEditingController mobileController,
//   required int itemCount,
//   required double totalAmount,
//   required Color primaryColor,
//   required VoidCallback onSave,
//   VoidCallback? onCancel,
// }) {
//   return showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) {
//       return Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: Container(
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
//           ),
//           padding: const EdgeInsets.all(24),
//           child: Form(
//             key: formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Center(
//                   child: Container(
//                     width: 50,
//                     height: 5,
//                     decoration: BoxDecoration(
//                       color: Colors.grey[300],
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 const Text('Save Order',
//                     style:
//                         TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 8),
//                 Text('Enter customer details to save this order',
//                     style: TextStyle(color: Colors.grey[600])),
//                 const SizedBox(height: 24),
//                 TextFormField(
//                   controller: nameController,
//                   validator: (v) =>
//                       v == null || v.length < 2 ? 'Invalid name' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: mobileController,
//                   maxLength: 10,
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   validator: (v) =>
//                       v == null || v.length != 10 ? 'Invalid mobile' : null,
//                 ),
//                 const SizedBox(height: 24),
//                 Text('$itemCount items • ₹$totalAmount'),
//                 const SizedBox(height: 24),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: onCancel ?? () => Navigator.pop(context),
//                         child: const Text('Cancel'),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () {
//                           if (formKey.currentState!.validate()) {
//                             onSave();
//                             Navigator.pop(context);
//                           }
//                         },
//                         style: ElevatedButton.styleFrom(
//                             backgroundColor: primaryColor),
//                         child: const Text('Save Order'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     },
//   );
// }

class SaveOrderBottomSheet extends StatelessWidget {
  const SaveOrderBottomSheet({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.mobileController,
    required this.itemCount,
    required this.totalAmount,
    required this.onSave,
    required this.onCancel,
    required this.primaryColor,
    this.title = 'Save Order',
    this.subtitle = 'Enter customer details to save this order',
    this.saveButtonText = 'Save Order',
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController mobileController;

  final int itemCount;
  final double totalAmount;

  final VoidCallback onSave;
  final VoidCallback onCancel;

  final Color primaryColor;
  final String title;
  final String subtitle;
  final String saveButtonText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dragHandle(),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              _nameField(),
              const SizedBox(height: 16),
              _mobileField(),
              const SizedBox(height: 24),
              _orderSummary(),
              const SizedBox(height: 24),
              _actionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: nameController,
      decoration: _inputDecoration(
        label: 'Customer Name',
        icon: Icons.person_outline,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter customer name';
        }
        if (value.length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _mobileField() {
    return TextFormField(
      controller: mobileController,
      maxLength: 10,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(
        label: 'Mobile Number',
        icon: Icons.phone_outlined,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter mobile number';
        }
        if (value.length != 10) {
          return 'Mobile number must be 10 digits';
        }
        return null;
      },
    );
  }

  Widget _orderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order Summary', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('$itemCount items',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Total Amount', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('₹$totalAmount',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
          ]),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                // textStyle: const TextStyle(color: Colors.white)
                ),
            child: Text(saveButtonText,style: const TextStyle(color: Colors.white),),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
