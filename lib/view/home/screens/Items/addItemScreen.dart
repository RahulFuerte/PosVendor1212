// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';

// class AddItemScreen extends StatefulWidget {
//   final String uid;
//   const AddItemScreen({required this.uid, super.key});

//   @override
//   State<AddItemScreen> createState() => _AddItemScreenState();
// }

// class _AddItemScreenState extends State<AddItemScreen> {
//   bool isChecked = false;
//   bool isLoading = true;
//   bool isUploading = false;
//   String selectedOption1 = '';
//   String selectedOption2 = '';
//   String selectedOption3 = '';
//   String baseVarient = 'Kg';
//   String selectedVariantUnit = 'Kg';
//   String priceType = "Fixed";
//   List<String> activeDepartments = [];
//   bool enableVariants = false;
//   bool enableAddons = false;

//   List<String> baseVarients = ['Kg', 'Liter', 'Item Per Pc'];
//   List<Map<String, dynamic>> variants = [];
//   List<Map<String, dynamic>> addons = [];

//   String? selectedSize;

//   final List<String> sizeOptions = [
//     'Small',
//     'Medium',
//     'Large',
//     'Extra Large',
//   ];

//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   final TextEditingController foodNameController = TextEditingController();
//   final TextEditingController foodPriceController = TextEditingController();
//   final TextEditingController foodPrice2Controller = TextEditingController();
//   final TextEditingController foodPrice3Controller = TextEditingController();
//   final TextEditingController foodCodeController = TextEditingController();
//   final TextEditingController foodStockController = TextEditingController();
//   final TextEditingController foodDescriptionController = TextEditingController();
//   final TextEditingController variantQtyController = TextEditingController();
//   final TextEditingController variantPriceController = TextEditingController();
//   final TextEditingController addonNameController = TextEditingController();
//   final TextEditingController addonPriceController = TextEditingController();

//   String selectedDepartment = '';
//   File? selectedImage;
//   File? pdfFile;

//   @override
//   void initState() {
//     super.initState();
//     _initializeData();
//   }

//   @override
//   void dispose() {
//     // foodNameController.dispose();
//     // foodPriceController.dispose();
//     // foodCodeController.dispose();
//     // foodStockController.dispose();
//     // foodDescriptionController.dispose();
//     super.dispose();
//   }

//   Future<void> _initializeData() async {
//     await _fetchActiveDepartments();
//     if (mounted) {
//       setState(() {
//         selectedDepartment = activeDepartments.isNotEmpty ? activeDepartments[0] : '';
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _fetchActiveDepartments() async {
//     try {
//       final snapshot = await _firestore.collection('AllAdmins').doc(widget.uid).collection('departments').get();

//       activeDepartments.clear();
//       for (var doc in snapshot.docs) {
//         var data = doc.data();
//         if (data['status'] == 'Active') {
//           activeDepartments.add(data['name']);
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching departments: $e');
//     }
//   }

//   Future<void> updateAllFoodItemsUid() async {
//     final firestore = FirebaseFirestore.instance;

//     // Path to the subcollection
//     final collectionRef = firestore.collection('AllAdmins').doc('+919265280309').collection('foodItems');

//     try {
//       // 1. Get all documents in that subcollection
//       QuerySnapshot querySnapshot = await collectionRef.get();

//       // 2. Initialize a batch
//       WriteBatch batch = firestore.batch();

//       // 3. Loop through documents and add them to the batch
//       for (var doc in querySnapshot.docs) {
//         batch.update(doc.reference, {'uid': '+919265280309'});
//       }

//       // 4. Commit the batch
//       await batch.commit();
//       print("Successfully updated ${querySnapshot.docs.length} items.");
//     } catch (e) {
//       print("Error performing batch update: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Screen s = Screen(context);

//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         backgroundColor: white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_rounded, color: black),
//           onPressed: () {
//             _clearControllers();
//             Navigator.pop(context);
//           },
//         ),
//         title: const Text(
//           'Add Item',
//           style: TextStyle(
//             color: black,
//             fontFamily: 'tabfont',
//             fontSize: 19,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.upload_file, color: black),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => BulkUploadScreen(
//                     uid: widget.uid,
//                     activeDepartments: activeDepartments,
//                     onUploadComplete: () {
//                       _fetchActiveDepartments().then((_) {
//                         if (mounted) {
//                           setState(() {
//                             selectedDepartment = activeDepartments.isNotEmpty ? activeDepartments[0] : '';
//                           });
//                         }
//                       });
//                     },
//                   ),
//                 ),
//               );
//             },
//           ),
//           const SizedBox(width: 10),
//           IconButton(
//             icon: const Icon(Icons.update, color: black),
//             onPressed: () async {
//               // If no PDF selected, open picker first
//               final service = SheetalDataService();
//               if (pdfFile == null) {
//                 await _pickPdfFile();
//                 return;
//               }

//               // Try to print and clear menu (best-effort)
//               try {
//                 service.printMenuSummary();
//               } catch (_) {}
//               try {
//                 await service.clearExistingMenuData();
//               } catch (_) {}

//               // Upload the selected PDF
//               try {
//                 await service.processAndUploadMenu(pdfFile!);
//                 _showSnackBar('PDF uploaded successfully');
//                 setState(() {
//                   pdfFile = null;
//                 });
//               } catch (e) {
//                 _showSnackBar('Error uploading PDF: $e');
//               }
//             },
//           ),
//         ],
//         centerTitle: true,
//       ),
//       body: PopScope(
//         canPop: true,
//         onPopInvoked: (didPop) {
//           if (didPop) _clearControllers();
//         },
//         child: isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: primaryColor),
//               )
//             : SingleChildScrollView(
//                 padding: EdgeInsets.all(18),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Image picker section
//                     _buildImagePicker(s),

//                     SizedBox(height: s.scale(24)),

//                     // Form fields
//                     _buildFormSection(s),

//                     SizedBox(height: s.scale(32)),

//                     // Submit button
//                     // _buildSubmitButton(s),

//                     SizedBox(height: s.scale(24)),
//                   ],
//                 ),
//               ),
//       ),
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(12),
//         child: _buildSubmitButton(s),
//       ),
//     );
//   }

//   Widget _buildImagePicker(Screen s) {
//     return Card(
//       elevation: 5,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Padding(
//         padding: EdgeInsets.all(s.scale(20)),
//         child: Column(
//           children: [
//             // Image preview
//             Container(
//               height: s.scale(150),
//               width: s.scale(150),
//               decoration: BoxDecoration(
//                 color: backgroundColor,
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(
//                   color: primaryColor.withOpacity(0.3),
//                   width: 2,
//                 ),
//               ),
//               child: selectedImage != null
//                   ? ClipRRect(
//                       borderRadius: BorderRadius.circular(14),
//                       child: Image.file(
//                         selectedImage!,
//                         fit: BoxFit.cover,
//                       ),
//                     )
//                   : Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.fastfood_rounded,
//                           size: s.scale(60),
//                           color: primaryColor.withOpacity(0.5),
//                         ),
//                         SizedBox(height: s.scale(8)),
//                         Text(
//                           'Add Image',
//                           style: TextStyle(
//                             color: grey,
//                             fontSize: s.scale(12),
//                           ),
//                         ),
//                       ],
//                     ),
//             ),

//             SizedBox(height: s.scale(16)),

//             // Image picker buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 _buildImageButton(
//                   icon: Icons.photo_library_rounded,
//                   label: 'Gallery',
//                   onTap: _pickImageFromGallery,
//                   s: s,
//                 ),
//                 SizedBox(width: s.scale(16)),
//                 _buildImageButton(
//                   icon: Icons.camera_alt_rounded,
//                   label: 'Camera',
//                   onTap: _pickImageFromCamera,
//                   s: s,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildImageButton({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     required Screen s,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         padding: EdgeInsets.symmetric(
//           horizontal: s.scale(20),
//           vertical: s.scale(12),
//         ),
//         decoration: BoxDecoration(
//           color: primaryColor.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Row(
//           children: [
//             Icon(icon, color: primaryColor, size: s.scale(20)),
//             SizedBox(width: s.scale(8)),
//             Text(
//               label,
//               style: TextStyle(
//                 color: primaryColor,
//                 fontWeight: FontWeight.w600,
//                 fontSize: s.scale(14),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFormSection(Screen s) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Department dropdown
//         AppDropdown(
//           heading: 'Select Department',
//           items: activeDepartments,
//           value: selectedDepartment.isEmpty ? null : selectedDepartment,
//           hint: "Choose department",
//           onChanged: (val) {
//             setState(() {
//               selectedDepartment = val;
//             });
//           },
//         ),

//         MyTextField(
//           controller: foodNameController,
//           hintText: 'Enter item name',
//           cstmLable: 'Item Name',
//           prefixIcon: Icons.shopping_bag_outlined,
//         ),

//         MyTextField(
//           controller: foodCodeController,
//           hintText: 'Enter item code',
//           cstmLable: 'Item Code',
//           keyboardType: TextInputType.number,
//           prefixIcon: Icons.qr_code_rounded,
//         ),
//         AppDropdown(
//           heading: 'Item Unit',
//           items: baseVarients,
//           value: baseVarient.isEmpty ? null : baseVarient,
//           hint: "Choose department",
//           onChanged: (val) {
//             setState(() {
//               baseVarient = val;
//             });
//           },
//         ),

//         MyTextField(
//           controller: foodPriceController,
//           hintText: 'Enter item price 1 here',
//           cstmLable: 'Item Price - 1 (₹)',
//           keyboardType: TextInputType.number,
//           prefixIcon: Icons.currency_rupee_rounded,
//         ),

//         MyTextField(
//           controller: foodPrice2Controller,
//           hintText: 'Enter item price 2 here',
//           cstmLable: 'Item Price - 2 (₹)',
//           keyboardType: TextInputType.number,
//           prefixIcon: Icons.currency_rupee_rounded,
//         ),
//         MyTextField(
//           controller: foodPrice3Controller,
//           hintText: 'Enter item price 3 here',
//           cstmLable: 'Item Price - 3 (₹)',
//           keyboardType: TextInputType.number,
//           prefixIcon: Icons.currency_rupee_rounded,
//         ),

//         Row(
//           children: [
//             const Text(
//               "Price Type",
//               style: TextStyle(
//                 letterSpacing: 1.3,
//                 fontSize: 15,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const Spacer(),
//             ChoiceChip(
//               selectedColor: primaryColor,
//               showCheckmark: false,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               label: const Text("Fixed"),
//               labelStyle: TextStyle(
//                 color: priceType == "Fixed" ? Colors.white : primaryColor,
//                 fontWeight: FontWeight.w600,
//               ),
//               selected: priceType == "Fixed",
//               onSelected: (v) {
//                 setState(() {
//                   priceType = "Fixed";
//                   foodPriceController.clear();
//                   foodPrice2Controller.clear();
//                   foodPrice3Controller.clear();
//                 });
//               },
//             ),
//             const SizedBox(
//               width: 7,
//             ),
//             ChoiceChip(
//               selectedColor: primaryColor,
//               showCheckmark: false,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               label: const Text("Open"),
//               labelStyle: TextStyle(
//                 color: priceType == "Open" ? Colors.white : primaryColor,
//                 fontWeight: FontWeight.w600,
//               ),
//               selected: priceType == "Open",
//               onSelected: (v) {
//                 setState(() {
//                   priceType = "Open";
//                   foodPriceController.text = "0";
//                   foodPrice2Controller.text = "0";
//                   foodPrice3Controller.text = "0";
//                 });
//               },
//             ),
//           ],
//         ),

//         // ================= MANUAL VARIANTS =================
//         const SizedBox(height: 10),
//         CheckboxListTile(
//           contentPadding: EdgeInsets.zero,
//           title: const Text(
//             "Add Variants",
//             style: TextStyle(
//               letterSpacing: 1.3,
//               fontSize: 15,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           value: enableVariants,
//           onChanged: (v) {
//             setState(() {
//               enableVariants = v!;
//               if (!enableVariants) {
//                 variants.clear();
//                 variantQtyController.clear();
//                 variantPriceController.clear();
//                 selectedSize = null;
//               }
//             });
//           },
//         ),

//         const SizedBox(height: 10),

//         if (enableVariants) ...[
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Select Unit',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
//               ),
//               const SizedBox(height: 5),
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.grey[200],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: DropdownButtonFormField<String>(
//                   value: selectedVariantUnit,
//                   items: ['Kg', 'Gm', 'Ml', 'Liter', 'Item Per Pc', 'Size']
//                       .map(
//                         (e) => DropdownMenuItem(
//                           value: e,
//                           child: Text(e),
//                         ),
//                       )
//                       .toList(),
//                   onChanged: (v) {
//                     if (v == null) return;
//                     setState(() {
//                       selectedVariantUnit = v;
//                       selectedSize = null;
//                       variantQtyController.clear();
//                     });
//                   },
//                   decoration: const InputDecoration(
//                     border: InputBorder.none,
//                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // ================= SIZE SELECTION =================
//           if (selectedVariantUnit == 'Size') ...[
//             const SizedBox(height: 15),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Select Size',
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
//                 ),
//                 const SizedBox(height: 5),
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: DropdownButtonFormField<String>(
//                     value: selectedSize,
//                     items: sizeOptions
//                         .map(
//                           (e) => DropdownMenuItem(
//                             value: e,
//                             child: Text(e),
//                           ),
//                         )
//                         .toList(),
//                     onChanged: (v) {
//                       setState(() => selectedSize = v);
//                     },
//                     decoration: const InputDecoration(
//                       border: InputBorder.none,
//                       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],

//           // ================= QTY INPUT =================
//           if (selectedVariantUnit != 'Size') ...[
//             const SizedBox(height: 15),
//             MyTextField(
//               controller: variantQtyController,
//               keyboardType: TextInputType.number,
//               hintText: 'Qty',
//               cstmLable: 'Quantity',
//             ),
//           ],
//           const SizedBox(height: 15),
//           MyTextField(
//             controller: variantPriceController,
//             keyboardType: TextInputType.number,
//             hintText: 'Enter variant price manually',
//             cstmLable: 'Variant Price',
//           ),

//           // ================= ADD MANUAL VARIANT =================
//           Align(
//             alignment: Alignment.centerRight,
//             child: GestureDetector(
//               onTap: () {
//                 if (variantPriceController.text.isEmpty) return;
//                 if (selectedVariantUnit == 'Size' && selectedSize == null) return;

//                 setState(() {
//                   variants.add({
//                     'unitType': selectedVariantUnit,
//                     'size': selectedVariantUnit == 'Size' ? selectedSize : null,
//                     'qty': selectedVariantUnit == 'Size' ? 1 : double.parse(variantQtyController.text),
//                     'price': double.parse(variantPriceController.text),
//                   });
//                 });

//                 variantQtyController.clear();
//                 variantPriceController.clear();
//                 selectedSize = null;
//               },
//               child: Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 15),
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(30),
//                   color: primaryColor,
//                 ),
//                 child: const Text(
//                   'ADD VARIANT',
//                   style: TextStyle(color: Colors.white, fontFamily: "tabfont"),
//                 ),
//               ),
//             ),
//           ),

//           // ================= VARIANT LIST =================
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: variants.length,
//             itemBuilder: (context, index) {
//               final v = variants[index];
//               return ListTile(
//                 title: Text(
//                   v['unitType'] == 'Size' ? v['size'] : "${v['qty']} ${v['unitType']}",
//                 ),
//                 trailing: Text(
//                   "₹${v['price']}",
//                   style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
//                 ),
//               );
//             },
//           ),
//         ],

//         CheckboxListTile(
//           contentPadding: EdgeInsets.zero,
//           title: const Text(
//             "Add-Ons",
//             style: TextStyle(
//               letterSpacing: 1.3,
//               fontSize: 15,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           value: enableAddons,
//           onChanged: (v) {
//             setState(() {
//               enableAddons = v!;
//               if (!enableAddons) addons.clear();
//             });
//           },
//         ),

//         if (enableAddons) ...[
//           Column(
//             children: [
//               MyTextField(
//                 controller: addonNameController,
//                 hintText: "Enter Addon Name",
//                 cstmLable: "Addon Name",
//               ),
//               MyTextField(
//                 controller: addonPriceController,
//                 keyboardType: TextInputType.number,
//                 hintText: "Enter Addon Price",
//                 cstmLable: "Addon Price",
//               ),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: GestureDetector(
//                   onTap: () {
//                     if (addonNameController.text.isEmpty || addonPriceController.text.isEmpty) return;

//                     setState(() {
//                       addons.add({
//                         "name": addonNameController.text,
//                         "price": double.parse(addonPriceController.text),
//                       });
//                     });

//                     addonNameController.clear();
//                     addonPriceController.clear();
//                   },
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(horizontal: 15),
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(30),
//                       color: primaryColor,
//                     ),
//                     child: const Text(
//                       'ADD ADDON',
//                       style: TextStyle(color: Colors.white, fontFamily: "tabfont"),
//                     ),
//                   ),
//                 ),
//               ),
//               ListView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: addons.length,
//                 itemBuilder: (c, i) {
//                   return ListTile(
//                     title: Text(addons[i]['name']),
//                     trailing: Text("₹${addons[i]['price']}"),
//                   );
//                 },
//               )
//             ],
//           )
//         ],

//         MyTextField(
//           controller: foodStockController,
//           hintText: 'Enter stock quantity',
//           cstmLable: 'Stock Quantity',
//           keyboardType: TextInputType.number,
//           prefixIcon: Icons.inventory_2_outlined,
//         ),

//         MyTextField(
//           controller: foodDescriptionController,
//           hintText: 'Enter item description',
//           cstmLable: 'Description',
//           prefixIcon: Icons.description_outlined,
//         ),
//       ],
//     );
//   }

//   Widget _buildSubmitButton(Screen s) {
//     return SizedBox(
//       width: double.infinity,
//       height: s.scale(56),
//       child: ElevatedButton(
//         onPressed: isUploading ? null : _handleSubmit,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: primaryColor,
//           foregroundColor: white,
//           elevation: 5,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//         child: isUploading
//             ? const SizedBox(
//                 height: 20,
//                 width: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 ))
//             : Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.check_circle_outline, size: s.scale(22)),
//                   SizedBox(width: s.scale(12)),
//                   Text(
//                     'Add Item',
//                     style: TextStyle(
//                       fontSize: s.scale(17),
//                       fontWeight: FontWeight.w600,
//                       letterSpacing: 1,
//                     ),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }

//   void _clearControllers() {
//     // foodNameController.clear();
//     // foodPriceController.clear();
//     // foodCodeController.clear();
//     // foodStockController.clear();
//     // foodDescriptionController.clear();
//   }

//   Future<void> _pickImageFromGallery() async {
//     final returnImage = await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (returnImage != null) {
//       setState(() {
//         selectedImage = File(returnImage.path);
//       });
//     }
//   }

//   Future<void> _pickImageFromCamera() async {
//     final returnImage = await ImagePicker().pickImage(source: ImageSource.camera);
//     if (returnImage != null) {
//       setState(() {
//         selectedImage = File(returnImage.path);
//       });
//     }
//   }

//   Future<void> _pickPdfFile() async {
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['pdf'],
//       );
//       if (result != null && result.files.single.path != null) {
//         setState(() {
//           pdfFile = File(result.files.single.path!);
//         });
//         _showSnackBar('Selected PDF: ${result.files.single.name}');
//       } else {
//         _showSnackBar('No PDF selected');
//       }
//     } catch (e) {
//       _showSnackBar('Error picking PDF: $e');
//     }
//   }

//   Future<void> _handleSubmit() async {
//     final String foodName = foodNameController.text.trim();
//     final String foodCode = foodCodeController.text.trim();
//     final String foodPrice = foodPriceController.text.trim();
//     final String foodPrice2 = foodPrice2Controller.text.trim();
//     final String foodPrice3 = foodPrice3Controller.text.trim();
//     final String stocks = foodStockController.text.trim();
//     final String description = foodDescriptionController.text.trim();
//     final bool isHot = isChecked;

//     if (foodName.isEmpty || foodCode.isEmpty || foodPrice.isEmpty || stocks.isEmpty) {
//       _showSnackBar('Please fill all required fields');
//       return;
//     }

//     setState(() => isUploading = true);

//     try {
//       await _createItem(
//         context,
//         foodName,
//         foodCode,
//         foodPrice,
//         foodPrice2,
//         foodPrice3,
//         stocks,
//         description,
//         isHot,
//         widget.uid,
//       );
//     } finally {
//       setState(() => isUploading = false);
//     }
//   }

//   Future<void> _createItem(
//     BuildContext context,
//     String foodName,
//     String foodCode,
//     String foodPrice,
//     String foodPrice2,
//     String foodPrice3,
//     String foodStock,
//     String foodDescription,
//     bool isHot,
//     String phoneNo,
//   ) async {
//     try {
//       User? user = _auth.currentUser;
//       if (user == null) return;

//       final formattedVariants = variants.map((v) {
//         return {
//           'qty': v['qty'],
//           'unit': v['unit'] ?? v['unitType'],
//           'price': v['price'],
//           'size': v['size'] ?? '',
//         };
//       }).toList();

//       String imagePath = selectedImage != null ? await _uploadImageToStorage(selectedImage) : '';

//       final foodCollection = _firestore.collection('AllAdmins').doc(widget.uid).collection('foodItems');

//       await foodCollection.add({
//         'name': foodName,
//         'foodCode': foodCode,
//         'price': priceType == "Open" ? 0 : double.tryParse(foodPrice) ?? 0,
//         'price2': priceType == "Open" ? 0 : double.tryParse(foodPrice2) ?? 0,
//         'price3': priceType == "Open" ? 0 : double.tryParse(foodPrice3) ?? 0,
//         'priceType': priceType,
//         'baseVariant': baseVarient,
//         'variants': formattedVariants,
//         'addons': addons,
//         'uid': phoneNo,
//         'imagePath': imagePath,
//         'department': selectedOption1,
//         'tax': selectedOption2,
//         'stocks': int.tryParse(foodStock) ?? 0,
//         'description': foodDescription,
//         'isHot': isHot,
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Item added successfully')),
//       );

//       /// Clear form
//       foodNameController.clear();
//       foodCodeController.clear();
//       foodPriceController.clear();
//       foodPrice2Controller.clear();
//       foodPrice3Controller.clear();
//       foodStockController.clear();
//       foodDescriptionController.clear();
//       variantQtyController.clear();
//       variantPriceController.clear();

//       setState(() {
//         variants.clear();
//         addons.clear();
//         enableVariants = false;
//         enableAddons = false;
//         priceType = "Fixed";
//         selectedImage = null;
//       });
//     } catch (e) {
//       debugPrint('Error creating food item: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Something went wrong')),
//       );
//     }
//   }

//   Future<String> _uploadImageToStorage(File? image) async {
//     if (image == null) return '';

//     try {
//       final ref = FirebaseStorage.instance.ref().child('food_images/${DateTime.now().millisecondsSinceEpoch}');
//       await ref.putFile(image);
//       return await ref.getDownloadURL();
//     } catch (e) {
//       debugPrint('Error uploading image: $e');
//       return '';
//     }
//   }

//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: primaryColor,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     }
//   }
// }
