import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../tab_screen/view-model/widgets/offline_bill_status_widget.dart';
import '../tab_screen/view-model/widgets/offline_status_indicator.dart';
import '../tab_screen/view-model/backend/complete_offline_data_manager.dart';
import '../tab_screen/view-model/backend/price_utils.dart';
import '../tab_screen/view-model/constants/constants.dart';

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
        backgroundColor: white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offline Bills',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'tabfont',
            fontSize: 19,
          ),
        ),
        actions: [
          const OfflineStatusIndicator(showWhenOnline: true),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadAllBills,
            tooltip: 'Refresh Bills',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.withOpacity(0.1),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Offline Bill Status Widget
                    OfflineBillStatusWidget(
                      adminUid: widget.adminUid,
                      onSyncCompleted: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Offline bills synced successfully'),
                            backgroundColor: primaryColor,
                          ),
                        );
                        _loadAllBills();
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // All Bills Section
                    Container(
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'All Bills (${_bills.length})',
                                style: const TextStyle(
                                  fontFamily: 'tabfont',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          if (_isLoading)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: CircularProgressIndicator(color: primaryColor),
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                      ),
                                      child: const Text('Retry', style: TextStyle(color: white)),
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
                  ],
                ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPending ? Colors.orange.withOpacity(0.1) : primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isPending ? Icons.sync_problem : Icons.check_circle,
            color: isPending ? Colors.orange : primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          'Bill #${billId.length > 8 ? billId.substring(0, 8) : billId}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'tabfont',
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customerName,
              style: TextStyle(
                fontFamily: 'fontmain',
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            if (billDate != null)
              Text(
                _formatDate(billDate),
                style: TextStyle(
                  fontFamily: 'fontmain',
                  fontSize: 11,
                  color: Colors.grey.shade500,
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: primaryColor,
                fontFamily: 'tabfont',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPending ? Colors.orange.withOpacity(0.1) : primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPending ? 'Pending' : 'Synced',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isPending ? Colors.orange : primaryColor,
                ),
              ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.receipt, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bill #${bill['id']?.toString() ?? 'Unknown'}',
                style: const TextStyle(
                  fontFamily: 'tabfont',
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer', bill['customer_name']?.toString() ?? 'Unknown'),
              _buildDetailRow('Phone', bill['customer_phone']?.toString() ?? 'N/A'),
              _buildDetailRow('Total', '₹${PriceUtils.safePriceToString(bill['total_amount'] ?? bill['total'])}'),
              _buildDetailRow('Payment', bill['payment_method']?.toString() ?? 'N/A'),
              _buildDetailRow('Status', bill['sync_status']?.toString() ?? 'Unknown'),
              if (bill['bill_date'] != null)
                _buildDetailRow('Date', _formatDate(DateTime.fromMillisecondsSinceEpoch(bill['bill_date'] as int))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'fontmain',
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'fontmain',
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}