import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';
import 'package:pos/core/utils/price_utils.dart';

class MenuItem extends StatelessWidget {
  MenuItem({
    super.key,
    required this.context,
    required this.imagePath,
    required this.text,
    required this.code,
    required this.price,
    required this.stocks,
    this.variants,
    this.baseVariant,
    this.onAdd,
    this.imagerecordId,
    this.price2,
    this.price3,
    this.priceType,
    this.addons,
  });

  final BuildContext context;
  final String imagePath;
  final String text;
  final String code;
  final String price;
  final String? price2;
  final String? price3;
  final String? priceType;
  final String stocks;
  final String? baseVariant;
  final List<dynamic>? variants;
  final List<dynamic>? addons;
  final String? imagerecordId;

  final void Function(
    String id,
    String name,
    String price,
    int quantity,
    String unit,
    num unitQty,
    List<Map<String, dynamic>> addonList,
  )? onAdd;

  final List<Map<String, dynamic>> selectedAddons = [];
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (priceType == "Open") {
              _showOpenPriceBottomSheet(context);
            } else if (variants != null && variants!.isNotEmpty) {
              _showVariantBottomSheet(context);
            } else {
              _addToCart(text, price, 1, baseVariant ?? '', 1, []);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// IMAGE
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedBlobImage(
                      imageUrl: imagePath,
                      tableName: 'food_items',
                      recordId: imagerecordId ?? code,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: const Center(
                          child: Icon(
                        Icons.fastfood,
                        size: 40,
                        color: Colors.black45,
                      )),
                    ),
                  ),
                ),

                /// NAME
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: MyText(
                    text: text,
                    maxLines: 2,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                /// PRICE + ADD
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: MyText(
                          text: PriceUtils.formatPrice(double.tryParse(price) ?? 0),
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          fontSize: 17.5,
                          color: appbar1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        /// STOCK BADGE
        // Positioned(
        //   top: 8,
        //   left: 8,
        //   child: _stockBadge(),
        // ),
      ],
    );
  }

  /// STOCK BADGE
  Widget _stockBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          MyText(
            text: stocks,
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  /// ADD TO CART
  void _addToCart(
      String name, String price, int quantity, String unit, num unitQty, List<Map<String, dynamic>> addons) {
    onAdd?.call(imagerecordId ?? code, name, price, quantity, unit, unitQty, addons);
  }

  void _showOpenPriceBottomSheet(BuildContext context) {
    final TextEditingController priceController = TextEditingController();
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// TITLE
                    MyText(
                      text: text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),

                    const SizedBox(height: 15),

                    /// PRICE INPUT
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Enter Amount",
                        prefixText: "₹ ",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// QUANTITY
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (quantity > 1) {
                              setModalState(() => quantity--);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        MyText(
                          text: '$quantity',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// ADD BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appbar1,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          if (priceController.text.isEmpty) {
                            return;
                          }

                          double enteredPrice = double.tryParse(priceController.text) ?? 0;

                          if (enteredPrice <= 0) return;

                          _addToCart(
                            text,
                            enteredPrice.toStringAsFixed(2),
                            quantity,
                            "Open Price",
                            1,
                            [],
                          );

                          Navigator.pop(ctx);
                        },
                        child: const MyText(
                          text: "ADD TO CART",
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// VARIANT BOTTOM SHEET
  void _showVariantBottomSheet(BuildContext context) {
    Map<String, dynamic> selectedVariant = variants!.first;
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// TITLE
                    Center(
                      child: MyText(
                        text: text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// VARIANT CHIPS
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: variants!.map((v) {
                        final bool isSelected = v == selectedVariant;
                        final bool isSize = v['unit'] == "Size";

                        return ChoiceChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Column(
                            children: [
                              MyText(
                                text: isSize ? (v['size']?.toString() ?? '') : "${v['qty'] ?? ''} ${v['unit'] ?? ''}",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              MyText(
                                text: '₹${v['price']}',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : appbar1,
                              ),
                            ],
                          ),
                          selectedColor: appbar1,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onSelected: (_) {
                            setModalState(() {
                              selectedVariant = v;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    if (addons != null && addons!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const MyText(
                        text: "Add Ons",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: addons!.map((addon) {
                          final bool selected = selectedAddons.contains(addon);

                          return FilterChip(
                            selected: selected,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            showCheckmark: false,
                            label: Column(
                              children: [
                                MyText(
                                  text: "${addon['name']}",
                                  color: selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                MyText(
                                  text: "₹${addon['price']}",
                                  color: selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ],
                            ),
                            selectedColor: appbar1,
                            onSelected: (v) {
                              setModalState(() {
                                if (v) {
                                  if (addon['multi'] == false) {
                                    selectedAddons.clear(); // only one allowed
                                  }
                                  selectedAddons.add(addon);
                                } else {
                                  selectedAddons.remove(addon);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 10),

                    /// QUANTITY
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (quantity > 1) {
                              setModalState(() => quantity--);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        MyText(
                          text: '$quantity',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// ADD BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appbar1,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          double basePrice = double.parse(selectedVariant['price'].toString());

                          final bool isSize = selectedVariant['unit'] == "Size";

                          List<Map<String, dynamic>> addonList = [];

                          for (var a in selectedAddons) {
                            double p = double.parse(a['price'].toString());

                            addonList.add({
                              "name": a['name'],
                              "price": p,
                            });
                          }

                          _addToCart(
                            text,
                            basePrice.toStringAsFixed(2),
                            quantity,
                            isSize
                                ? (selectedVariant['size']?.toString() ?? '')
                                : (selectedVariant['unit']?.toString() ?? ''),
                            (selectedVariant['qty'] as num?)?.toInt() ?? 1,
                            addonList,
                          );

                          Navigator.pop(ctx);
                        },
                        child: const MyText(
                          text: 'ADD TO CART',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
