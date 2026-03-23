import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/reports/bill_wise_report.dart';
import 'package:pos/view/home/reports/customer_wise_report.dart';
import 'package:pos/view/home/reports/date_wise_report.dart';
import 'package:pos/view/home/reports/item_wise_report.dart';
import 'package:pos/view/home/reports/sales_report_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class ReportNavBar extends StatelessWidget {
  final String currentReport;
  final String uid;
  final String adminUid;

  const ReportNavBar({
    Key? key,
    required this.currentReport,
    required this.uid,
    required this.adminUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildNavChip(context, 'Sales', SalesReportScreen(uid: uid, adminUid: adminUid)),
          _buildNavChip(context, 'Bill-wise', BillwiseReportScreen(uid: uid, adminUid: adminUid)),
          _buildNavChip(context, 'Item-wise', ItemwiseReportScreen(uid: uid, adminUid: adminUid)),
          _buildNavChip(context, 'Date-wise', DatewiseReportScreen(uid: uid, adminUid: adminUid)),
          _buildNavChip(context, 'Customer-wise', CustomerWiseReport(uid: uid, adminUid: adminUid)),
        ],
      ),
    );
  }

  Widget _buildNavChip(BuildContext context, String label, Widget screen) {
    final isSelected = currentReport == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: MyText(
          text: label,
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected && !isSelected) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
          }
        },
        selectedColor: primaryColor,
        backgroundColor: Colors.grey[200],
        checkmarkColor: Colors.white,
      ),
    );
  }
}
