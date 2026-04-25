import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
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

class TableManagementScreen extends StatelessWidget {
  final String phoneNo;
  final String? role;
  final String? adminId;
  final Future<void> Function(String tableId)? onTableSelected;

  const TableManagementScreen({super.key, this.onTableSelected, required this.phoneNo, this.role, this.adminId});

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const MyText(
          text: 'Table Management',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color.fromARGB(255, 12, 107, 15)),
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
        adminPhoneNo: adminId ?? phoneNo,
      ),
      body: tableProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          ? const Center(child: MyText(text: 'No tables found. Add some!'))
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
            onPressed: () => _showAddTableDialog(context, tableProvider),
            backgroundColor: appbar1,
            tooltip: 'Add New Table',
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
        title: const MyText(text: 'Add New Table', fontWeight: FontWeight.bold),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Table Name / Number',
            hintText: 'e.g., Table 21, VIP-1',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const MyText(text: 'Cancel', color: Colors.grey),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.addTable(controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const MyText(text: 'Add', color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(TableProvider provider) {
    final occupiedCount = provider.tables.where((t) => t.isOccupied).length;
    final totalCount = provider.tables.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', totalCount.toString(), Colors.blue),
          _buildStatItem('Occupied', occupiedCount.toString(), Colors.orange),
          _buildStatItem('Free', (totalCount - occupiedCount).toString(), Colors.green),
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
                    child: const MyText(
                      text: 'Occupied',
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
              const MyText(
                text: 'Available',
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
          decoration: BoxDecoration(
            color: appbar1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyText(
                text: '${table.tableNumber} Summary',
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
            child: const MyText(text: 'Clear Table', color: Colors.red, fontWeight: FontWeight.bold),
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
        title: const MyText(text: 'Clear Table?', fontWeight: FontWeight.bold),
        content: MyText(
            text:
                'Are you sure you want to clear table ${table.tableNumber}? This will remove all items and mark it as available.'),
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
            child: const MyText(text: 'Clear', color: Colors.white),
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
    if (onTableSelected != null) {
      onTableSelected!(tableId);
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
  }
}
