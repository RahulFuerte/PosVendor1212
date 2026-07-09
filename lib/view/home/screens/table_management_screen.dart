import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/models/table_model.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TableManagementScreen extends StatefulWidget {
  final Future<void> Function(String tableId)? onTableSelected;

  const TableManagementScreen({super.key, this.onTableSelected});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  String phoneNo = '';
  bool _tourShowing = false;
  TutorialCoachMark? _tourMark;
  TourProvider? _tourProvider;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tourProvider = context.read<TourProvider>();
      _tourProvider!.addListener(_onTourStateChanged);
      _checkTour();
    });
  }

  void _checkTour() {
    final tourProvider = context.read<TourProvider>();
    if (tourProvider.isTourActive && tourProvider.currentStep == 25) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showTour();
      });
    }
  }

  void _onTourStateChanged() {
    final tourProvider = context.read<TourProvider>();
    if (!tourProvider.isTourActive) return;
    if (tourProvider.currentStep == 25 && !_tourShowing) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showTour();
      });
    }
  }

  void _showTour() {
    if (_tourShowing) return;
    _tourShowing = true;
    final tourProvider = context.read<TourProvider>();

    final targets = [
      TargetFocus(
        identify: "table_stats",
        keyTarget: TourKeys.tableStatsKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 25,
                title: AppLocale.tourTitleTableView.getString(context),
                description: AppLocale.tourDescTableView.getString(context),
                onNext: () => controller.next(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "table_add",
        keyTarget: TourKeys.tableAddKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 26,
                title: AppLocale.tourTitleTableAdd.getString(context),
                description: AppLocale.tourDescTableAdd.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
    ];

    final validTargets = targets.where((t) {
      final k = t.keyTarget;
      return k == null || k.currentContext != null;
    }).toList();
    if (validTargets.isEmpty) {
      _tourShowing = false;
      if (tourProvider.isTourActive) tourProvider.setStep(27);
      return;
    }

    _tourMark = TutorialCoachMark(
      targets: validTargets,
      hideSkip: true,
      colorShadow: Colors.black.withOpacity(0.85),
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        _tourShowing = false;
        if (tourProvider.isTourActive) {
          tourProvider.setStep(27);
        }
      },
      onSkip: () {
        _tourShowing = false;
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
  }

  @override
  void dispose() {
    _tourProvider?.removeListener(_onTourStateChanged);
    _tourMark?.finish();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: MyText(
            text: AppLocale.tableManagement.getString(context),
            fontSize: 17,
            color: Colors.black,
            fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => tableProvider.loadTables(),
          ),
        ],
      ),
      drawer: MyDrawer(
        phoneNo: phoneNo,
        adminPhoneNo: phoneNo,
      ),
      body: tableProvider.isLoading
          ? const _TableSkeleton()
          : Consumer<SubscriptionProvider>(
              builder: (context, subProvider, _) {
                if (!subProvider.hasPermission("TableBooking", checkView: true)) {
                  return const AccessDeniedWidget(feature: "Table Booking");
                }

                return Column(
                  children: [
                    // Stats Row
                    _buildStatsRow(tableProvider),

                    Expanded(
                      child: tableProvider.tables.isEmpty
                          ? Center(child: MyText(text: AppLocale.noTablesFoundAddSome.getString(context)))
                          : Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: tableProvider.tables.length,
                                itemBuilder: (context, index) {
                                  final table = tableProvider.tables[index];
                                  return _buildTableCard(context, table);
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: Consumer<SubscriptionProvider>(
        builder: (context, subProvider, _) {
          if (!subProvider.hasPermission("TableBooking", checkCreate: true)) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton(
            key: TourKeys.tableAddKey,
            onPressed: () => _showAddTableDialog(context, tableProvider),
            backgroundColor: appbar1,
            tooltip: AppLocale.addNewTable.getString(context),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          );
        },
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, TableProvider provider) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: MyText(text: AppLocale.addNewTable.getString(context), fontWeight: FontWeight.bold),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocale.tableNameNumber.getString(context),
            hintText: AppLocale.tableNameHint.getString(context),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MyText(text: AppLocale.cancel.getString(context), color: Colors.grey),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.addTable(controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: MyText(text: AppLocale.add.getString(context), color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(TableProvider provider) {
    final occupiedCount = provider.tables.where((t) => t.isOccupied).length;
    final totalCount = provider.tables.length;

    return Container(
      key: TourKeys.tableStatsKey,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(AppLocale.statTotal.getString(context), totalCount.toString(), Colors.blue),
          _buildStatItem(AppLocale.statOccupied.getString(context), occupiedCount.toString(), Colors.orange),
          _buildStatItem(AppLocale.statFree.getString(context), (totalCount - occupiedCount).toString(), Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        MyText(
          text: value,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        MyText(
          text: label,
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ],
    );
  }

  Widget _buildTableCard(BuildContext context, TableModel table) {
    final bool isOccupied = table.isOccupied;

    return GestureDetector(
      onTap: () => _handleTableSelection(context, table.id),
      onLongPress: () {
        if (isOccupied) {
          _showTableSummaryDialog(context, table);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isOccupied ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOccupied ? Colors.orange : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_bar_rounded,
              size: 32,
              color: isOccupied ? Colors.orange : Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            MyText(
              text: table.tableNumber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isOccupied ? Colors.orange.shade900 : Colors.black87,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (isOccupied)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: MyText(
                      text: AppLocale.occupied.getString(context),
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (table.customerName != null && table.customerName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 8, right: 8),
                      child: MyText(
                        text: table.customerName!,
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              )
            else
              MyText(
                text: AppLocale.available.getString(context),
                fontSize: 9,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            if (isOccupied && table.subtotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: MyText(
                  text: '₹${table.subtotal.toStringAsFixed(0)}',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTableSummaryDialog(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: appbar1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyText(
                text: '${table.tableNumber}${AppLocale.summary.getString(context)}',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (table.customerName != null && table.customerName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16),
                      const SizedBox(width: 8),
                      MyText(
                        text: '${table.customerName} (${table.customerPhone ?? 'No Phone'})',
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
              const MyText(
                text: 'Items',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: table.items.length,
                  itemBuilder: (context, index) {
                    final item = table.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: '${item['name']} x ${item['quantity']}',
                              fontSize: 13,
                            ),
                          ),
                          MyText(
                            text: '₹${(item['price'] * item['quantity']).toStringAsFixed(0)}',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const MyText(
                    text: 'Total Amount',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  MyText(
                    text: '₹${table.subtotal.toStringAsFixed(0)}',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: appbar1,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showClearTableConfirmation(context, table);
            },
            child:
                MyText(text: AppLocale.clearTable.getString(context), color: Colors.red, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: appbar1),
            child: const MyText(text: 'Close', color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showClearTableConfirmation(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: MyText(text: AppLocale.clearTableQ.getString(context), fontWeight: FontWeight.bold),
        content: MyText(text: AppLocale.clearTableMsg.getString(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const MyText(text: 'Cancel', color: Colors.grey),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<TableProvider>(context, listen: false).clearTable(table.id);
              Navigator.pop(context);
              SnackBarUtils.showInfo(context, 'Table ${table.tableNumber} cleared');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: MyText(text: AppLocale.clear.getString(context), color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _handleTableSelection(BuildContext context, String tableId) {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);

    // 1. Force-select the table (no toggle — occupied tables must always become selected)
    tableProvider.setSelectedTable(tableId);

    // 2. Load the new table's cart into PrintProvider
    final newTable = tableProvider.tables.firstWhere((t) => t.id == tableId);
    printProvider.setCart(newTable.items, newTable.subtotal);

    // 3. Set order type to Dine-In
    orderTypeProvider.setOrderType(OrderType.dineIn);

    // 4. If we have onTableSelected callback, call it, otherwise navigate back or to restaurant screen
    if (widget.onTableSelected != null) {
      widget.onTableSelected!(tableId);
    } else {
      // Find the Navigation state and switch to RestaurantScreen (index 1)
      final navigationState = context.findAncestorStateOfType<State<Navigation>>() as dynamic;
      if (navigationState != null) {
        navigationState.setState(() {
          navigationState.currentIndex = 1; // Assuming index 1 is RestaurantScreen
        });
      } else {
        // Fallback for standalone use
        Navigator.pop(context);
      }
    }
  } // Close build
} // Close _TableManagementScreenState

class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          // Stats Row Skeleton
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: _skeletonBox(height: 80)),
                const SizedBox(width: 12),
                Expanded(child: _skeletonBox(height: 80)),
                const SizedBox(width: 12),
                Expanded(child: _skeletonBox(height: 80)),
              ],
            ),
          ),
          // Grid Skeleton
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: 12,
              itemBuilder: (context, index) => _skeletonBox(height: 120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
