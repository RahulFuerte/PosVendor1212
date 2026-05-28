import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:provider/provider.dart';


class DynamicTableSelector extends StatelessWidget {
  const DynamicTableSelector({super.key});

  static Future<String?> show(BuildContext context) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DynamicTableSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MyText(text: AppLocale.selectTable.getString(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => tableProvider.loadTables(),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          if (tableProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (tableProvider.tables.isEmpty)
             Expanded(child: Center(child: MyText(text: AppLocale.noTablesFound.getString(context))))
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: tableProvider.tables.length,
                itemBuilder: (context, index) {
                  final table = tableProvider.tables[index];
                  final bool isSelected = tableProvider.selectedTableId == table.id;
                  final bool isOccupied = table.isOccupied;

                  return GestureDetector(
                    onTap: () => Navigator.pop(context, table.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? primaryColor.withOpacity(0.1) 
                            : isOccupied 
                                ? Colors.orange.withOpacity(0.05) 
                                : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected 
                              ? primaryColor 
                              : isOccupied 
                                  ? Colors.orange 
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_bar_rounded,
                            color: isSelected 
                                ? primaryColor 
                                : isOccupied 
                                    ? Colors.orange 
                                    : Colors.grey.shade400,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          MyText(
                            text: table.tableNumber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          if (isOccupied)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: MyText(
                                text: '₹${table.subtotal.toStringAsFixed(0)}',
                                fontSize: 10,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const MyText(text: 'Close', color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
