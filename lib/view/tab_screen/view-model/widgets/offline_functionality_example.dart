import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/database_service.dart';
import '../backend/unified_database_service.dart';
import '../backend/enhanced_offline_manager.dart';
import 'offline_status_banner.dart';
import 'offline_status_indicator.dart';

/// Example widget demonstrating offline functionality
class OfflineFunctionalityExample extends StatefulWidget {
  final String adminUid;

  const OfflineFunctionalityExample({
    super.key,
    required this.adminUid,
  });

  @override
  State<OfflineFunctionalityExample> createState() => _OfflineFunctionalityExampleState();
}

class _OfflineFunctionalityExampleState extends State<OfflineFunctionalityExample> {
  List<Map<String, dynamic>> _foodItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  Future<void> _loadFoodItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final foodItems = await databaseService.getFoodItems(widget.adminUid);
      
      setState(() {
        _foodItems = foodItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load food items: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addTestItem() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      final newItem = {
        'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Test Item ${DateTime.now().millisecondsSinceEpoch}',
        'price': 10.0,
        'department': 'Test Department',
        'food_code': 'TEST${DateTime.now().millisecondsSinceEpoch}',
        'description': 'Test item created offline',
        'stocks': 100,
        'is_hot': false,
        'tax': 'GST',
      };

      await databaseService.saveFoodItem(widget.adminUid, newItem);
      
      // Refresh the list
      await _loadFoodItems();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test item added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Functionality Demo'),
        actions: [
          // Show offline status indicator in app bar
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: OfflineStatusIndicator(showWhenOnline: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline status banner
          const OfflineStatusBanner(),
          
          // Offline data statistics
          if (databaseService is UnifiedDatabaseService) ...[
            // Padding(
            //   padding: const EdgeInsets.all(16.0),
            //   child: DetailedOfflineStatus(adminUid: widget.adminUid),
            // ),
          ],
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadFoodItems,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addTestItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Test Item'),
                  ),
                ),
              ],
            ),
          ),
          
          // Food items list
          Expanded(
            child: _buildFoodItemsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFoodItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_foodItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No food items found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add some items or check your internet connection',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _foodItems.length,
      itemBuilder: (context, index) {
        final item = _foodItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                item['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(item['name']?.toString() ?? 'Unknown Item'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price: \$${item['price']?.toString() ?? '0.00'}'),
                Text('Department: ${item['department']?.toString() ?? 'Unknown'}'),
                if (item['food_code'] != null)
                  Text('Code: ${item['food_code']}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item['sync_status'] == 1) // Pending sync
                  const Icon(
                    Icons.sync_problem,
                    color: Colors.orange,
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                Text(
                  item['sync_status'] == 1 ? 'Pending' : 'Synced',
                  style: TextStyle(
                    fontSize: 10,
                    color: item['sync_status'] == 1 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

/// Simple demo page to show offline functionality
class OfflineDemoPage extends StatelessWidget {
  const OfflineDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OfflineFunctionalityExample(
      adminUid: 'demo_admin', // Replace with actual admin UID
    );
  }
}