import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../tab_screen/view-model/widgets/offline_bill_status_widget.dart';
import '../tab_screen/view-model/widgets/offline_status_indicator.dart';
import '../tab_screen/view-model/backend/complete_offline_data_manager.dart';
import '../tab_screen/view-model/backend/price_utils.dart';

/// Enhanced offline bill status screen with complete bill viewing capability
class OfflineBillStatusScreen extends StatefulWidget {
  final String adminUid;

  const OfflineBillStatusScreen({
    Key? key,
    required this.adminUid,
  }) : super(key: key);

  @override
  State<OfflineBillStatusScreen> createState() => _OfflineBillStatusScreenState();
}

class _OfflineBillStatusScreenState extends State<OfflineBillStatusScreen> {
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAndLoadBills();
  }

  Future<void> _initializeAndLoadBills() async {
    try {
      await _offlineDataManager.initialize();
      await _loadAllBills();
    } catch (e) {
      developer.log('Error initializing offline bill screen: $e', name: 'OfflineBillStatusScreen');
      setState(() {
        _errorMessage = 'Failed to load bills: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllBills() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load all bills ensuring offline availability
      final bills = await _offlineDataManager.ensureBillsOfflineAvailability(widget.adminUid);
      
      setState(() {
        _bills = bills;
        _isLoading = false;
      });

      developer.log('Loaded ${bills.length} bills for offline viewing', name: 'OfflineBillStatusScreen');
    } catch (e) {
      developer.log('Error loading bills: $e', name: 'OfflineBillStatusScreen');
      setState(() {
        _errorMessage = 'Failed to load bills: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Bills & Offline Status'),
            SizedBox(width: 8),
            OfflineStatusIndicator(showWhenOnline: false),
          ],
        ),
        backgroundColor: Colors.blue[50],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllBills,
            tooltip: 'Refresh Bills',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.withOpacity(0.1),
            child: const Text(
              'Offline Bill Status',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offline Bill Status Widget
                  OfflineBillStatusWidget(
                    adminUid: widget.adminUid,
                    onSyncCompleted: () {
                      // Show success message when sync completes
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline bills synced successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Reload bills after sync
                      _loadAllBills();
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // All Bills Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'All Bills (${_bills.length})',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_errorMessage.isNotEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage,
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadAllBills,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (_bills.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No bills found',
                                      style: TextStyle(color: Colors.grey, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _bills.length,
                              itemBuilder: (context, index) {
                                final bill = _bills[index];
                                return _buildBillCard(bill);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final billId = bill['id']?.toString() ?? 'Unknown';
    final billDate = bill['bill_date'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(bill['bill_date'] as int)
        : null;
    final customerName = bill['customer_name']?.toString() ?? 'Unknown Customer';
    final totalAmount = PriceUtils.safePriceToString(bill['total_amount'] ?? bill['total']);
    final syncStatus = bill['sync_status']?.toString() ?? 'unknown';
    final isPending = syncStatus == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.orange : Colors.green,
          child: Icon(
            isPending ? Icons.sync_problem : Icons.check_circle,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          'Bill #${billId.length > 8 ? billId.substring(0, 8) : billId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: $customerName'),
            if (billDate != null)
              Text('Date: ${_formatDate(billDate)}'),
            Text(
              'Status: ${isPending ? 'Pending Sync' : 'Synced'}',
              style: TextStyle(
                color: isPending ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹$totalAmount',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isPending)
              const Icon(
                Icons.cloud_upload,
                size: 16,
                color: Colors.orange,
              ),
          ],
        ),
        onTap: () {
          _showBillDetails(bill);
        },
      ),
    );
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill #${bill['id']?.toString() ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer', bill['customer_name']?.toString() ?? 'Unknown'),
              _buildDetailRow('Phone', bill['customer_phone']?.toString() ?? 'N/A'),
              _buildDetailRow('Total Amount', '₹${PriceUtils.safePriceToString(bill['total_amount'] ?? bill['total'])}'),
              _buildDetailRow('Payment Method', bill['payment_method']?.toString() ?? 'N/A'),
              _buildDetailRow('Sync Status', bill['sync_status']?.toString() ?? 'Unknown'),
              if (bill['bill_date'] != null)
                _buildDetailRow('Date', _formatDate(DateTime.fromMillisecondsSinceEpoch(bill['bill_date'] as int))),
              if (bill['items'] != null)
                _buildDetailRow('Items', bill['items'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}