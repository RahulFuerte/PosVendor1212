import 'package:flutter/material.dart';
import '../frontend/sync_aware_appbar.dart';
import 'sync_status_banner.dart';
import 'sync_status_widget.dart';
import 'sync_status_page.dart';

/// Example screen showing how to integrate sync status components
class SyncIntegrationExample extends StatefulWidget {
  final String adminUid;

  const SyncIntegrationExample({
    Key? key,
    required this.adminUid,
  }) : super(key: key);

  @override
  State<SyncIntegrationExample> createState() => _SyncIntegrationExampleState();
}

class _SyncIntegrationExampleState extends State<SyncIntegrationExample> {
  void _navigateToSyncStatusPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SyncStatusPage(adminUid: widget.adminUid),
      ),
    );
  }

  void _onSyncCompleted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sync completed successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the sync-aware app bar
      appBar: SyncAwareAppBar(
        adminUid: widget.adminUid,
        title: 'Product Dashboard',
        onSyncCompleted: _onSyncCompleted,
        additionalActions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings action
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync status banner at the top
          SyncStatusBanner(
            adminUid: widget.adminUid,
            onTap: _navigateToSyncStatusPage,
            showOnlyWhenRelevant: true,
          ),
          
          // Main content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sync status widget card
                SyncStatusWidget(
                  adminUid: widget.adminUid,
                  onSyncCompleted: _onSyncCompleted,
                  onRetryRequested: () {
                    print('Retry requested by user');
                  },
                  showPendingCount: true,
                  showLastSyncTime: true,
                  showManualSyncButton: true,
                ),
                
                const SizedBox(height: 16),
                
                // Example content cards
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restaurant_menu),
                    title: const Text('Food Items'),
                    subtitle: const Text('Manage your menu items'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to food items
                    },
                  ),
                ),
                
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.category),
                    title: const Text('Departments'),
                    subtitle: const Text('Organize your products'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to departments
                    },
                  ),
                ),
                
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt),
                    title: const Text('Bills'),
                    subtitle: const Text('View transaction history'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to bills
                    },
                  ),
                ),
                
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sync_alt),
                    title: const Text('Sync Management'),
                    subtitle: const Text('Detailed sync status and controls'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _navigateToSyncStatusPage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}