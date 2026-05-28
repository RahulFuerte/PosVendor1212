import 'package:flutter/foundation.dart';
import 'package:pos/data/models/table_model.dart';

import '../services/table_service.dart';

class TableProvider extends ChangeNotifier {
  final TableService _tableService = TableService();
  List<TableModel> _tables = [];
  String? _selectedTableId;
  bool _isLoading = false;

  TableProvider() {
    loadTables();
  }

  List<TableModel> get tables => _tables;
  String? get selectedTableId => _selectedTableId;
  bool get isLoading => _isLoading;

  TableModel? get selectedTable {
    if (_selectedTableId == null) return null;
    try {
      return _tables.firstWhere((element) => element.id == _selectedTableId);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadTables() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Fetch from remote or demo data based on current mode
      final remoteTables = await _tableService.getTables();

      _tables = remoteTables;
    } catch (e) {
      // In case of error, clear tables to avoid showing stale data
      _tables = [];
    } finally {
      _isLoading = false;
      if (_tables.length == 1) {
        _selectedTableId = _tables[0].id;
      }
      notifyListeners();
    }
  }


  Future<void> addTable(String tableNumber) async {
    try {
      final remoteTable = await _tableService.addTable(tableNumber);
      _tables.add(remoteTable);
      notifyListeners();
    } catch (e) {
      print('Error adding table: $e');
    }
  }

  void selectTable(String? tableId) {
    if (_selectedTableId == tableId) {
      // Toggle selection: if already selected, deselect it
      _selectedTableId = null;
    } else {
      _selectedTableId = tableId;
    }
    notifyListeners();
  }

  /// Force-selects a table without the toggle behaviour.
  /// Use this when you always want the table to become selected (e.g. from TableManagementScreen).
  void setSelectedTable(String tableId) {
    _selectedTableId = tableId;
    notifyListeners();
  }

  Future<void> setTableCart(String tableId, List<Map<String, dynamic>> items,
      {String? customerName, String? customerPhone, String? lastOrderId, bool createKot = true}) async {
    final index = _tables.indexWhere((element) => element.id == tableId);
    if (index != -1) {
      // 1. Calculate subtotal and process items (Always recalculate totals)
      double subtotal = 0.0;
      final processedItems = items.map((item) {
        final Map<String, dynamic> newItem = Map<String, dynamic>.from(item);
        final itemPrice = (newItem['price'] as num).toDouble();
        final itemQty = (newItem['quantity'] as num).toDouble();
        final itemTotal = itemPrice * itemQty;

        newItem['total'] = itemTotal;
        subtotal += itemTotal;
        return newItem;
      }).toList();

      final status = processedItems.isNotEmpty ? 'Occupied' : 'Available';

      // 2. Optimistic local update
      final updatedTable = _tables[index].copyWith(
        items: processedItems,
        subtotal: subtotal,
        isOccupied: processedItems.isNotEmpty,
        customerName: customerName ?? _tables[index].customerName,
        customerPhone: customerPhone ?? _tables[index].customerPhone,
        lastOrderId: lastOrderId ?? _tables[index].lastOrderId,
      );

      _tables[index] = updatedTable;
      notifyListeners();

      try {
        // 3. Sync to backend in background
        await _tableService.updateTableStatus(
          tableId,
          status,
          items: processedItems,
          subtotal: subtotal,
          customerName: customerName ?? _tables[index].customerName,
          customerPhone: customerPhone ?? _tables[index].customerPhone,
          currentOrderId: lastOrderId ?? _tables[index].lastOrderId,
          createKot: createKot,
        );
        // No need to update local state again from response unless we want to sync IDs
      } catch (e) {
        print('Error syncing table cart: $e');
        // Optionally: implement a retry mechanism or revert local state if crucial
      }
    }
  }

  Future<void> setTableOrderId(String tableId, String? orderId) async { 
    final index = _tables.indexWhere((element) => element.id == tableId);
    if (index != -1) {
      try {
        await _tableService.updateTableStatus(
          tableId,
          _tables[index].isOccupied ? 'Occupied' : 'Available',
          currentOrderId: orderId,
        );
        final updatedTable = _tables[index].copyWith(lastOrderId: orderId);
        _tables[index] = updatedTable;
        notifyListeners();
      } catch (e) {
        print('Error syncing table order ID: $e');
      }
    }
  }

  Future<void> clearTable(String tableId) async {
    final index = _tables.indexWhere((element) => element.id == tableId);
    if (index != -1) {
      try {
        // Update remote with cleared state
        await _tableService.updateTableStatus(
          tableId,
          'Available',
          items: [],
          subtotal: 0.0,
          customerName: "",
          customerPhone: "",
          currentOrderId: null,
          createKot: false,
        );

        final updatedTable = _tables[index].copyWith(
          isOccupied: false,
          customerName: null,
          customerPhone: null,
          lastOrderId: null,
          items: [],
          subtotal: 0.0,
        );

        _tables[index] = updatedTable;
        notifyListeners();
      } catch (e) {
        print('Error clearing table on remote: $e');
      }
    }
  }

  Future<void> assignCustomerToTable(String tableId, String name, String phone) async {
    final index = _tables.indexWhere((element) => element.id == tableId);
    if (index != -1) {
      try {
        await _tableService.updateTableStatus(
          tableId,
          'Occupied',
          customerName: name,
          customerPhone: phone,
        );

        final updatedTable = _tables[index].copyWith(
          customerName: name,
          customerPhone: phone,
          isOccupied: true,
        );

        _tables[index] = updatedTable;
        notifyListeners();
      } catch (e) {
        print('Error assigning customer to table: $e');
      }
    }
  }

  void clear() {
    _selectedTableId = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadTables() async {
    // Clear existing data first
    _tables = [];
    _selectedTableId = null;
    await loadTables();
  }

  void clearAll() {
    _tables = [];
    _selectedTableId = null;
    _isLoading = false;
    notifyListeners();
  }
}
