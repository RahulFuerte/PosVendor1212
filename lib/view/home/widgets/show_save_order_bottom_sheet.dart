import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter/services.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pos/data/services/customer_service.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class SaveOrderBottomSheet extends StatefulWidget {
  const SaveOrderBottomSheet({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.mobileController,
    required this.addressController,
    required this.gstController,
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
  final TextEditingController addressController;
  final TextEditingController gstController;

  final int itemCount;
  final double totalAmount;

  final void Function(String? customerId) onSave;
  final VoidCallback onCancel;

  final Color primaryColor;
  final String title;
  final String subtitle;
  final String saveButtonText;

  @override
  State<SaveOrderBottomSheet> createState() => _SaveOrderBottomSheetState();
}

class _SaveOrderBottomSheetState extends State<SaveOrderBottomSheet> {
  final ScrollController _listScrollController = ScrollController();
  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final CustomerService _customerService = CustomerService();
  List<Map<String, dynamic>> selectedItemsDetails = [];
  List<CustomerModel> _customers = [];
  String? _selectedCustomerId;
  bool _isFetchingCustomers = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isFetchingCustomers = true);
    try {
      final customers = await _customerService.getCustomers();
      setState(() {
        _customers = customers;
      });
    } catch (e) {
      developer.log('Error fetching customers: $e', name: 'SaveOrderBottomSheet');
    } finally {
      setState(() => _isFetchingCustomers = false);
    }
  }

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
          key: widget.formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dragHandle(),
                const SizedBox(height: 20),
                MyText(text: widget.title, fontSize: 24, fontWeight: FontWeight.bold),
                const SizedBox(height: 8),
                MyText(text: widget.subtitle, fontSize: 14, color: Colors.grey[600]),
                const SizedBox(height: 24),
                _customerAutoCompleteField(),
                const SizedBox(height: 16),
                _mobileField(),
                const SizedBox(height: 24),
                _addressField(),
                const SizedBox(height: 24),
                gstField(),
                const SizedBox(height: 24),
                _orderSummary(),
                const SizedBox(height: 24),
                _actionButtons(context),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Show only amount when compact view, otherwise show label + amount

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: 'Grand Total',
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          MyText(
                            text: PriceUtils.formatPrice(widget.totalAmount),
                            fontSize: 20,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildIconButton(
                            icon: Icons.receipt_long_outlined,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 10),
                          _buildIconButton(
                            icon: Icons.bookmark_outline,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 10),
                          _buildIconButton(
                            icon: Icons.print,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  Widget _buildItemsList(PrintProvider printProvider) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.15,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        controller: _listScrollController,
        itemCount: selectedItemsDetails.length,
        itemBuilder: (context, index) {
          return _buildCartItem(index, printProvider);
        },
      ),
    );
  }

  Widget _buildCartItem(int index, PrintProvider printProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: appbar1, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: selectedItemsDetails[index]['name'],
                  overflow: TextOverflow.ellipsis,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                MyText(
                  text: '${PriceUtils.formatPrice(selectedItemsDetails[index]['price'])} × ${selectedItemsDetails[index]['quantity']}',
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
          _buildQuantityControls(index, printProvider),
          const SizedBox(width: 8),
          _buildDeleteButton(index, printProvider),
        ],
      ),
    );
  }

  Widget _buildQuantityControls(int index, PrintProvider printProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (selectedItemsDetails[index]['quantity'] > 1) {
                  selectedItemsDetails[index]['quantity']--;
                  // subtotal -= selectedItemsDetails[index]['price'];
                } else {
                  // subtotal -= selectedItemsDetails[index]['price'];
                  selectedItemsDetails.removeAt(index);
                }
                // _updateCart();
              });
            },
            child: Container(
              color: appbar1,
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.remove, color: white, size: 28),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MyText(
              text: "${selectedItemsDetails[index]['quantity']}",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                selectedItemsDetails[index]['quantity']++;
                // subtotal += selectedItemsDetails[index]['price'];
                // _updateCart();
              });
            },
            child: Container(
              color: appbar1,
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.add, color: white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(int index, PrintProvider printProvider) {
    return InkWell(
      onTap: () {
        setState(() {
          // subtotal -= selectedItemsDetails[index]['price'] * selectedItemsDetails[index]['quantity'];
          selectedItemsDetails.removeAt(index);
          // _updateCart();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: appbar1,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _customerAutoCompleteField() {
    return RawAutocomplete<CustomerModel>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<CustomerModel>.empty();
        }
        return _customers.where((CustomerModel option) {
          return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
              option.phoneNumber.contains(textEditingValue.text);
        });
      },
      displayStringForOption: (CustomerModel option) => option.name,
      fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode,
          VoidCallback onFieldSubmitted) {
        // Sync original controller with autocomplete controller
        if (textEditingController.text.isEmpty && widget.nameController.text.isNotEmpty) {
          textEditingController.text = widget.nameController.text;
        }

        textEditingController.addListener(() {
          if (widget.nameController.text != textEditingController.text) {
            widget.nameController.text = textEditingController.text;
            // Clear ID if name changes manually
            if (_selectedCustomerId != null) {
              setState(() => _selectedCustomerId = null);
              // Also clear from PrintProvider if name manually changed
              Provider.of<PrintProvider>(context, listen: false).setCustomerDetails(id: null);
            }
          }
        });

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: _inputDecoration(
            label: 'Customer Name',
            icon: Icons.person_outline,
          ).copyWith(
            suffixIcon: _isFetchingCustomers
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter customer name';
            }
            return null;
          },
        );
      },
      onSelected: (CustomerModel selection) {
        // Update controllers
        widget.nameController.text = selection.name;
        widget.mobileController.text = selection.phoneNumber;
        widget.addressController.text = selection.address ?? '';
        widget.gstController.text = selection.gstNo ?? '';

        // Sync with PrintProvider
        final printProvider = Provider.of<PrintProvider>(context, listen: false);
        printProvider.setCustomerDetails(
          id: selection.id,
          name: selection.name,
          phone: selection.phoneNumber,
          gst: selection.gstNo,
          address: selection.address,
        );

        setState(() {
          _selectedCustomerId = selection.id;
        });
      },
      optionsViewBuilder:
          (BuildContext context, AutocompleteOnSelected<CustomerModel> onSelected, Iterable<CustomerModel> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              width: MediaQuery.of(context).size.width - 48, // Padding on both sides
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final CustomerModel option = options.elementAt(index);
                  return ListTile(
                    title: MyText(text: option.name),
                    subtitle: MyText(text: option.phoneNumber),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: widget.nameController,
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
      controller: widget.mobileController,
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

  Widget _addressField() {
    return TextFormField(
      controller: widget.addressController,
      keyboardType: TextInputType.text,
      decoration: _inputDecoration(
        label: 'Enter Address',
        icon: Icons.home,
      ),
    );
  }

  Widget gstField() {
    return TextFormField(
      controller: widget.gstController,
      keyboardType: TextInputType.text,
      decoration: _inputDecoration(
        label: 'Enter GST Number',
        icon: Icons.note,
      ),
    );
  }

  Widget _orderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MyText(text: 'Order Summary', color: Colors.grey[600]),
            const SizedBox(height: 4),
            MyText(text: '${widget.itemCount} items', fontSize: 16, fontWeight: FontWeight.w600),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            MyText(text: 'Total Amount', color: Colors.grey[600]),
            const SizedBox(height: 4),
            MyText(
              text: '₹${widget.totalAmount}',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
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
            onPressed: widget.onCancel,
            child: const MyText(text: 'Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (widget.formKey.currentState!.validate()) {
                widget.onSave(_selectedCustomerId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              // textStyle: const TextStyle(color: Colors.white)
            ),
            child: MyText(
              text: widget.saveButtonText,
              color: Colors.white,
            ),
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
      counterText: "",
      labelText: label,
      prefixIcon: Icon(icon, color: widget.primaryColor),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
