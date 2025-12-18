import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/view/tab_screen/view-model/widgets/offline_bill_sync_button.dart';

/// Example screen demonstrating offline bill functionality
class OfflineBillExampleScreen extends StatefulWidget {
  final String adminUid;
  final String userId;

  const OfflineBillExampleScreen({
    Key? key,
    required this.adminUid,
    required this.userId,
  }) : super(key: key);

  @override
  State<OfflineBillExampleScreen> createState() =>
      _OfflineBillExampleScreenState();
}

class _OfflineBillExampleScreenState extends State<OfflineBillExampleScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    final stats = await DirectPrintHelper.getOfflineBillStats(widget.adminUid);

    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sync button
                  OfflineBillSyncButton(
                    adminUid: widget.adminUid,
                    onSyncComplete: _loadStats,
                  ),
                  const SizedBox(height: 20),

                  // Statistics cards
                  _buildStatCard(
                    'Offline Bills',
                    _stats?['offlineBillsCount']?.toString() ?? '0',
                    Icons.cloud_off,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    'Synced Bills',
                    _stats?['syncedBillsCount']?.toString() ?? '0',
                    Icons.cloud_done,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    'Total Bills',
                    _stats?['totalBillsCount']?.toString() ?? '0',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    'Connection Status',
                    (_stats?['isConnected'] ?? false) ? 'Online' : 'Offline',
                    (_stats?['isConnected'] ?? false)
                        ? Icons.wifi
                        : Icons.wifi_off,
                    (_stats?['isConnected'] ?? false)
                        ? Colors.green
                        : Colors.red,
                  ),

                  const SizedBox(height: 24),

                  // Information section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How Offline Bills Work',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            '1. When offline, bills are saved locally',
                          ),
                          _buildInfoItem(
                            '2. Bills automatically sync when connection is restored',
                          ),
                          _buildInfoItem(
                            '3. You can manually trigger sync using the button above',
                          ),
                          _buildInfoItem(
                            '4. All offline bills are safely stored until synced',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
