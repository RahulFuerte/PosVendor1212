import 'package:flutter/material.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/cached_blob_image.dart';

class MenuItem extends StatelessWidget {
  const MenuItem({
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
  });

  final BuildContext context;
  final String imagePath;
  final String text;
  final String code;
  final String price;
  final String stocks;
  final String? baseVariant;
  final List<dynamic>? variants;
  final String? imagerecordId;

  /// Callback to add item to cart
  final void Function(
    String name,
    String price,
    int quantity,
    String unit,
    num unitQty,
  )? onAdd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (variants != null && variants!.isNotEmpty) {
              _showVariantBottomSheet(context);
            } else {
              _addToCart(
                text,
                price,
                1,
                baseVariant ?? '',
                1,
              );
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
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedBlobImage(
                      imageUrl: imagePath,
                      tableName: 'food_items',
                      recordId: imagerecordId ?? code,
                      width: double.infinity,
                      fit: BoxFit.fill,
                      errorWidget: Center(
                          child: const Icon(
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
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                /// VARIANT BADGE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Wrap(
                    spacing: 8, // horizontal space
                    runSpacing: 6, // vertical space when it wraps
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      variants != null && variants!.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: appbar1.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: appbar1.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    baseVariant ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: appbar1,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${variants!.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                      _codeBadge(),
                    ],
                  ),
                ),

                const Divider(thickness: 0.3),

                /// PRICE + ADD
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '₹${numberFormat.format(double.tryParse(price) ?? 0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: appbar1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ADD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
        Positioned(
          top: 8,
          left: 8,
          child: _stockBadge(),
        ),
      ],
    );
  }

  /// CODE BADGE
  Widget _codeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag, size: 12),
          const SizedBox(width: 4),
          Text(
            code.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
          Text(
            stocks,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// ADD TO CART
  void _addToCart(String name, String price, int quantity, String unit, num unitQty) {
    onAdd?.call(name, price, quantity, unit, unitQty);
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
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// VARIANT CHIPS
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: variants!.map((v) {
                        final bool isSelected = v == selectedVariant;

                        return ChoiceChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Column(
                            children: [
                              Text(
                                '${v['qty']} ${v['unit']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                '₹${v['price']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : appbar1,
                                ),
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
                        Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                          _addToCart(
                            text,
                            selectedVariant['price'].toString(),
                            quantity,
                            selectedVariant['unit'].toString(),
                            (selectedVariant['qty'] as num).toInt(),
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'ADD TO CART',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
