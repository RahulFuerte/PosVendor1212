import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/reports/bill_wise_report.dart';
import 'package:pos/view/home/reports/customer_wise_report.dart';
import 'package:pos/view/home/reports/date_wise_report.dart';
import 'package:pos/view/home/reports/item_wise_report.dart';
import 'package:pos/view/home/reports/sales_report_screen.dart';
import 'package:pos/view/home/reports/staff_wise_report.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportNavBar extends StatefulWidget {
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
  State<ReportNavBar> createState() => _ReportNavBarState();
}

class _ReportNavBarState extends State<ReportNavBar> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _role;

  @override
  void initState() {
    super.initState();
    // Initialize keys for all possible reports
    for (var label in ['Sales', 'Bill-wise', 'Item-wise', 'Date-wise', 'Customer-wise', 'Staff-wise']) {
      _itemKeys[label] = GlobalKey();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _role = prefs.getString('role');
      });
      
      // Use a slight delay to ensure the ListView has rendered its children
      // especially the conditional ones like 'Staff-wise'
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    if (!mounted) return;
    final key = _itemKeys[widget.currentReport];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If the current report is Staff-wise, we should show it even before role check
    // to avoid UI "lag" or "jumping"
    bool showStaffWise = _role == 'admin' || widget.currentReport == 'Staff-wise';

    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildNavChip(context, 'Sales', const SalesReportScreen()),
          _buildNavChip(context, 'Bill-wise', const BillwiseReportScreen()),
          _buildNavChip(context, 'Item-wise', const ItemwiseReportScreen()),
          _buildNavChip(context, 'Date-wise', const DatewiseReportScreen()),
          _buildNavChip(context, 'Customer-wise', const CustomerWiseReport()),
          if (showStaffWise)
            _buildNavChip(context, 'Staff-wise', const StaffWiseReportScreen()),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildNavChip(BuildContext context, String label, Widget screen) {
    final isSelected = widget.currentReport == label;
    return Padding(
      key: _itemKeys[label],
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        showCheckmark: false,
        label: MyText(
          text: label,
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected && !isSelected) {
            // Instant navigation to prevent 'Appearance Lag'
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => screen,
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 100),
              ),
            );
          }
        },
        selectedColor: primaryColor,
        backgroundColor: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? primaryColor : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
