import 'package:flutter/material.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class OrderTile extends StatelessWidget {
  final String bill;
  final int amount;
  final String time;
  final bool edited;
  final String typeText;
  final Color typeColor;
  final String customerName;
  final String paymentStatus;
  final String status;
  final VoidCallback onPrint;
  final VoidCallback onWhatsapp;
  final VoidCallback onTap;

  const OrderTile({
    super.key,
    required this.bill,
    required this.amount,
    required this.time,
    this.edited = false,
    required this.typeText,
    required this.typeColor,
    required this.customerName,
    required this.paymentStatus,
    required this.status,
    required this.onPrint,
    required this.onWhatsapp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isPaid = paymentStatus.toLowerCase() == 'paid';
    bool isCancelled = status == 'Cancelled';

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCancelled ? Colors.grey.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Opacity(
              opacity: isCancelled ? 0.6 : 1.0,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MyText(text: '#$bill', fontWeight: FontWeight.bold, fontSize: 16),
                            const SizedBox(width: 10),
                            StatusBadge(text: typeText, color: typeColor),
                            if (!isCancelled) ...[
                              const SizedBox(width: 8),
                              StatusBadge(
                                text: paymentStatus.toUpperCase(),
                                color: isPaid ? Colors.green : Colors.orange,
                                isGlass: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: MyText(
                                text: customerName,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            MyText(text: '$time${edited ? ' • Edited' : ''}', fontSize: 12, color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MyText(
                        text: PriceUtils.formatPrice(amount),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isCancelled ? Colors.grey : primaryColor,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                      const SizedBox(height: 8),
                      if (!isCancelled)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: InkWell(
                                onTap: onWhatsapp,
                                child: Icon(MdiIcons.whatsapp, color: Colors.green, size: 22),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: appbar1.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: InkWell(
                                onTap: onPrint,
                                child: Icon(Icons.print_rounded, color: appbar1, size: 20),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isCancelled)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: const MyText(
                  text: 'CANCELLED',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool isGlass;

  const StatusBadge({super.key, required this.text, required this.color, this.isGlass = false});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGlass ? color.withOpacity(0.1) : color,
        borderRadius: BorderRadius.circular(8),
        border: isGlass ? Border.all(color: color.withOpacity(0.2)) : null,
      ),
      child: MyText(
        text: text,
        color: isGlass ? color : Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class KOTTile extends StatelessWidget {
  final String id;
  final String kotNo;
  final String table;
  final List<dynamic> itemList;
  final String status;
  final DateTime? createdAt;
  final VoidCallback onStatusUpdate;
  final bool isUpdating;

  const KOTTile({
    super.key,
    required this.id,
    required this.kotNo,
    required this.table,
    required this.itemList,
    required this.status,
    required this.onStatusUpdate,
    this.createdAt,
    this.isUpdating = false,
  });

  Color _getStatusColor() {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade300;
      case 'Preparing':
        return Colors.blue.shade400;
      case 'Ready':
        return Colors.green.shade500;
      case 'Served':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }

  String _getNextAction() {
    switch (status) {
      case 'Pending':
        return 'START COOKING';
      case 'Preparing':
        return 'MARK AS READY';
      case 'Ready':
        return 'MARK AS SERVED';
      default:
        return '';
    }
  }

  String _getTimeAgo() {
    if (createdAt == null) return "Just now";
    final diff = DateTime.now().difference(createdAt!);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 30) return "${diff.inDays}d ago";
    if (diff.inDays < 365) return "${(diff.inDays / 30).floor()}mo ago";
    return "${(diff.inDays / 365).floor()}y ago";
  }

  @override
  Widget build(BuildContext context) {
    bool isUrgent = createdAt != null && DateTime.now().difference(createdAt!).inMinutes > 15 && status == 'Pending';
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.08),
                  statusColor.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: kotNo,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isUrgent ? Icons.error_outline : Icons.schedule_rounded,
                            size: 13,
                            color: isUrgent ? Colors.red : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          MyText(
                            text: _getTimeAgo(),
                            fontSize: 11,
                            color: isUrgent ? Colors.red : Colors.grey.shade500,
                            fontWeight: isUrgent ? FontWeight.bold : FontWeight.w600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      text: status.toUpperCase(),
                      color: statusColor,
                      isGlass: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.table_bar_rounded, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        MyText(
                          text: table,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// Items List Section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const MyText(
                      text: "ORDER ITEMS",
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...itemList.map((item) {
                  final name = item['name'] ?? '';
                  final qty = item['quantity'] ?? 1;
                  final variant = item['variant'] ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: MyText(
                            text: "${qty}x",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MyText(
                                text: name,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.85),
                              ),
                              if (variant.toString().isNotEmpty)
                                MyText(
                                  text: variant.toString(),
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          /// Action Button Section
          if (_getNextAction().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isUpdating ? null : onStatusUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: statusColor.withOpacity(0.6),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              status == 'Pending' ? Icons.play_arrow_rounded : Icons.check_circle_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            MyText(
                              text: _getNextAction(),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
