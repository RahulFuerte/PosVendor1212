// Dart imports:
import 'dart:developer' as developer;

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import '../../core/utils/price_utils.dart';
import '../../data/datasources/complete_offline_data_manager.dart';
import '../tab_screen/view-model/constants/constants.dart';
import '../tab_screen/view-model/widgets/offline_bill_status_widget.dart';
import '../tab_screen/view-model/widgets/offline_status_indicator.dart';
import '../../core/utils/snackbar_utils.dart';

/// Enhanced offline bill status screen with complete bill viewing capability
class OfflineBillStatusScreen extends StatefulWidget {
  const OfflineBillStatusScreen({Key? key}) : super(key: key);

  @override
  State<OfflineBillStatusScreen> createState() => _OfflineBillStatusScreenState();
}

class _OfflineBillStatusScreenState extends State<OfflineBillStatusScreen> {
  String adminUid = '';
  String uid = '';

  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Function to refresh the sync widget
  VoidCallback? _refreshSyncWidget;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      uid = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
    });
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
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _bills = []; // Clear existing bills to force refresh
      });

      // Re-initialize to clear any cached data
      await _offlineDataManager.initialize();

      // Load all bills ensuring offline availability (force refresh to get latest data)
      final bills = await _offlineDataManager.ensureBillsOfflineAvailability(adminUid, forceRefresh: true);

      if (!mounted) return;

      setState(() {
        _bills = bills;
        _isLoading = false;
      });

      // Also refresh the sync status widget
      _refreshSyncWidget?.call();

      developer.log('Loaded ${bills.length} bills for offline viewing', name: 'OfflineBillStatusScreen');
    } catch (e) {
      developer.log('Error loading bills: $e', name: 'OfflineBillStatusScreen');
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load bills: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        backgroundColor: white,
        elevation: 0,
        title: const MyText(
          text: 'Offline Bills',
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        actions: [
          const OfflineStatusIndicator(showWhenOnline: true),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadAllBills,
            tooltip: 'Refresh Bills',
          ),
        ],
      ),
      drawer: MyDrawer(
        phoneNo: uid,
        adminPhoneNo: adminUid,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offline Bill Status Widget
                  OfflineBillStatusWidget(
                    adminUid: adminUid,
                    onRefreshCallbackReady: (refreshCallback) {
                      _refreshSyncWidget = refreshCallback;
                    },
                    onSyncCompleted: () {
                      SnackBarUtils.showSuccess(context, 'Offline bills synced successfully');
                      _loadAllBills();
                    },
                  ),

                  const SizedBox(height: 16),

                  // All Bills Section
                  Container(
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long, color: primaryColor),
                            const SizedBox(width: 8),
                            MyText(
                              text: 'All Bills (${_bills.length})',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
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
                                  MyText(
                                    text: _errorMessage,
                                    color: Colors.red,
                                    fontFamily: 'Outfit',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadAllBills,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                    ),
                                    child: const MyText(text: 'Retry', color: white),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_bills.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  MyText(
                                    text: 'No bills found',
                                    color: Colors.grey[500],
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
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
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final billId = bill['id']?.toString() ?? 'Unknown';
    DateTime? billDate;
    try {
      final billDateValue = bill['bill_date'];
      if (billDateValue is int) {
        billDate = DateTime.fromMillisecondsSinceEpoch(billDateValue);
      } else if (billDateValue is String) {
        // Try parsing as milliseconds string first
        final parsed = int.tryParse(billDateValue);
        if (parsed != null) {
          billDate = DateTime.fromMillisecondsSinceEpoch(parsed);
        } else {
          // Try parsing as date string
          billDate = DateTime.tryParse(billDateValue);
        }
      }
    } catch (e) {
      billDate = null;
    }
    final customerName = bill['customer_name']?.toString() ?? 'Walk-in Customer';
    final totalAmount = PriceUtils.safePriceToString(bill['total_amount'] ?? bill['total']);

    // Handle sync_status as both int and String
    // 0 = synced, 1 = pending, 2 = conflict
    final syncStatusValue = bill['sync_status'];
    bool isPending = false;
    String syncStatusText = 'Unknown';

    if (syncStatusValue is int) {
      isPending = syncStatusValue == 1;
      syncStatusText = syncStatusValue == 0 ? 'Synced' : (syncStatusValue == 1 ? 'Pending' : 'Conflict');
    } else if (syncStatusValue is String) {
      final parsed = int.tryParse(syncStatusValue);
      if (parsed != null) {
        isPending = parsed == 1;
        syncStatusText = parsed == 0 ? 'Synced' : (parsed == 1 ? 'Pending' : 'Conflict');
      } else {
        isPending = syncStatusValue.toLowerCase() == 'pending';
        syncStatusText = syncStatusValue;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isPending ? Colors.orange.withOpacity(0.1) : primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isPending ? Icons.sync_problem : Icons.check_circle,
            color: isPending ? Colors.orange : primaryColor,
            size: 22,
          ),
        ),
        title: MyText(
          text: 'Bill #$billId',
          fontWeight: FontWeight.bold,
          fontSize: 15,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            MyText(
              text: customerName,
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Colors.grey.shade700,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (billDate != null)
              MyText(
                text: _formatDate(billDate),
                fontFamily: 'Outfit',
                fontSize: 11,
                color: Colors.grey.shade500,
                maxLines: 1,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MyText(
              text: '₹$totalAmount',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryColor,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPending ? Colors.orange.withOpacity(0.1) : primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: MyText(
                text: syncStatusText,
                fontSize: 10,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: isPending ? Colors.orange : primaryColor,
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
            const Icon(Icons.receipt, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: MyText(
                text: 'Bill #${bill['id']?.toString() ?? 'Unknown'}',
                fontSize: 16,
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
              _buildDetailRow('Status', _getSyncStatusText(bill['sync_status'])),
              if (bill['bill_date'] != null) _buildDetailRow('Date', _formatBillDate(bill['bill_date'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const MyText(text: 'Close'),
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
            child: MyText(
              text: label,
              fontFamily: 'Outfit',
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: MyText(
              text: value,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatBillDate(dynamic billDateValue) {
    DateTime? billDate;
    try {
      if (billDateValue is int) {
        billDate = DateTime.fromMillisecondsSinceEpoch(billDateValue);
      } else if (billDateValue is String) {
        final parsed = int.tryParse(billDateValue);
        if (parsed != null) {
          billDate = DateTime.fromMillisecondsSinceEpoch(parsed);
        } else {
          billDate = DateTime.tryParse(billDateValue);
        }
      }
    } catch (e) {
      return 'Unknown';
    }
    return billDate != null ? _formatDate(billDate) : 'Unknown';
  }

  String _getSyncStatusText(dynamic syncStatus) {
    if (syncStatus is int) {
      switch (syncStatus) {
        case 0:
          return 'Synced';
        case 1:
          return 'Pending';
        case 2:
          return 'Conflict';
        default:
          return 'Unknown';
      }
    } else if (syncStatus is String) {
      final parsed = int.tryParse(syncStatus);
      if (parsed != null) {
        return _getSyncStatusText(parsed);
      }
      return syncStatus;
    }
    return 'Unknown';
  }
}
