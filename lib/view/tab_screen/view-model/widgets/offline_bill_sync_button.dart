import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';

/// A button widget that shows offline bill count and allows manual sync
class OfflineBillSyncButton extends StatefulWidget {
  final String adminUid;
  final VoidCallback? onSyncComplete;

  const OfflineBillSyncButton({
    Key? key,
    required this.adminUid,
    this.onSyncComplete,
  }) : super(key: key);

  @override
  State<OfflineBillSyncButton> createState() => _OfflineBillSyncButtonState();
}

class _OfflineBillSyncButtonState extends State<OfflineBillSyncButton> {
  bool _isSyncing = false;
  int _offlineBillsCount = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await DirectPrintHelper.getOfflineBillStats(widget.adminUid);
    final isOnline = await DirectPrintHelper.isOnline();
    
    if (mounted) {
      setState(() {
        _offlineBillsCount = stats['offlineBillsCount'] ?? 0;
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _syncBills() async {
    if (_isSyncing || !_isOnline) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await DirectPrintHelper.syncOfflineBills(widget.adminUid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Synced ${result.billsSynced} bills successfully!'
                  : 'Sync failed: ${result.errorMessage}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          widget.onSyncComplete?.call();
          await _loadStats();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_offlineBillsCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      color: _isOnline ? Colors.orange.shade50 : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              _isOnline ? Icons.cloud_upload : Icons.cloud_off,
              color: _isOnline ? Colors.orange : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_offlineBillsCount bill${_offlineBillsCount > 1 ? 's' : ''} pending sync',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _isOnline
                        ? 'Tap to sync now'
                        : 'Will sync when online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (_isOnline)
              _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: _syncBills,
                      color: Colors.orange,
                    ),
          ],
        ),
      ),
    );
  }
}
