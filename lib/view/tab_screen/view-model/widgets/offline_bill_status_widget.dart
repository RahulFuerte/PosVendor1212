// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:provider/provider.dart';

// Project imports:

import '../../../../data/datasources/database_service.dart';
import '../../../../data/datasources/offline_bill_manager.dart';
import '../../../../data/datasources/unified_database_service.dart';
import '../constants/constants.dart';

/// Widget that displays offline bill sync status and provides manual sync functionality
class OfflineBillStatusWidget extends StatefulWidget {
  final String adminUid;
  final VoidCallback? onSyncCompleted;
  final void Function(VoidCallback refreshCallback)? onRefreshCallbackReady;

  const OfflineBillStatusWidget({
    Key? key,
    required this.adminUid,
    this.onSyncCompleted,
    this.onRefreshCallbackReady,
  }) : super(key: key);

  @override
  State<OfflineBillStatusWidget> createState() => _OfflineBillStatusWidgetState();
}

class _OfflineBillStatusWidgetState extends State<OfflineBillStatusWidget> {
  late final UnifiedDatabaseService _databaseService;
  
  StreamSubscription<OfflineBillSyncStatus>? _syncStatusSubscription;
  StreamSubscription<OfflineBillSyncResult>? _syncResultSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  
  int _offlineBillsCount = 0;
  bool _isConnected = false;
  bool _isSyncing = false;
  OfflineBillSyncStatus? _currentSyncStatus;
  String? _lastSyncError;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    // Get the DatabaseService from Provider and cast to UnifiedDatabaseService
    // This is safe because we know the Provider provides UnifiedDatabaseService
    _databaseService = Provider.of<DatabaseService>(context, listen: false) as UnifiedDatabaseService;
    _initializeService();
    _setupListeners();
    _loadInitialData();
    
    // Provide refresh callback to parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRefreshCallbackReady?.call(() {
        _loadInitialData();
      });
    });
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _syncResultSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      await _databaseService.initialize();
    } catch (e) {
      print('Failed to initialize database service: $e');
    }
  }

  void _setupListeners() {
    // Listen to offline bill sync status changes
    _syncStatusSubscription = _databaseService.offlineBillSyncStatusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _currentSyncStatus = status;
            _isSyncing = status == OfflineBillSyncStatus.syncing || 
                         status == OfflineBillSyncStatus.manualSyncStarted;
          });
        }
      },
    );

    // Listen to offline bill sync results
    _syncResultSubscription = _databaseService.offlineBillSyncResultStream.listen(
      (result) async {
        if (mounted) {
          // If sync was successful, immediately set count to 0 for synced bills
          // then refresh to get accurate count
          if (result.success) {
            setState(() {
              _isSyncing = false;
              _lastSyncTime = result.timestamp;
              _lastSyncError = null;
              // Immediately reduce count by synced bills for instant UI update
              _offlineBillsCount = (_offlineBillsCount - result.billsSynced).clamp(0, _offlineBillsCount);
            });
            
            // Then refresh to get accurate count from database
            await _loadOfflineBillsCount();
            widget.onSyncCompleted?.call();
          } else {
            setState(() {
              _isSyncing = false;
              _lastSyncTime = result.timestamp;
              _lastSyncError = result.errorMessage;
            });
          }
          
          // Show snackbar for sync results
          _showSyncResultSnackBar(result);
        }
      },
    );

    // Listen to connectivity changes
    _connectivitySubscription = _databaseService.connectivityStream.listen(
      (isConnected) {
        if (mounted) {
          setState(() {
            _isConnected = isConnected;
          });
        }
      },
    );
  }

  Future<void> _loadInitialData() async {
    await _loadOfflineBillsCount();
    await _loadConnectivityStatus();
  }

  Future<void> _loadOfflineBillsCount() async {
    try {
      final count = await _databaseService.getOfflineBillsCount(widget.adminUid);
      if (mounted) {
        setState(() {
          _offlineBillsCount = count;
        });
      }
    } catch (e) {
      print('Failed to load offline bills count: $e');
    }
  }

  Future<void> _loadConnectivityStatus() async {
    try {
      final isConnected = await _databaseService.isOnline();
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      print('Failed to load connectivity status: $e');
    }
  }

  Future<void> _manualSync() async {
    if (_isSyncing || !_isConnected) return;

    try {
      await _databaseService.manualSyncOfflineBills(widget.adminUid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manual sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSyncResultSnackBar(OfflineBillSyncResult result) {
    if (!mounted) return;

    String message;
    Color backgroundColor;
    IconData icon;

    if (result.success) {
      if (result.billsSynced > 0) {
        message = 'Successfully synced ${result.billsSynced} bills';
        if (result.billsSkipped > 0) {
          message += ' (${result.billsSkipped} skipped)';
        }
        if (result.conflictsResolved > 0) {
          message += ' (${result.conflictsResolved} conflicts resolved)';
        }
      } else {
        message = 'No bills to sync';
      }
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
    } else {
      message = 'Sync failed: ${result.errorMessage}';
      if (result.failedBillIds.isNotEmpty) {
        message += ' (${result.failedBillIds.length} bills failed)';
      }
      backgroundColor = Colors.red;
      icon = Icons.error;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: result.success ? 3 : 5),
        action: result.success && result.billsSynced > 0
            ? SnackBarAction(
                label: 'Details',
                textColor: Colors.white,
                onPressed: () => _showSyncDetails(result),
              )
            : null,
      ),
    );
  }

  void _showSyncDetails(OfflineBillSyncResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Bills Synced', result.billsSynced.toString()),
              _buildDetailRow('Bills Skipped', result.billsSkipped.toString()),
              _buildDetailRow('Conflicts Resolved', result.conflictsResolved.toString()),
              if (result.syncedBillIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Synced Bills:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...result.syncedBillIds.take(5).map((id) => Text('• ${id.length > 20 ? id.substring(0, 20) + '...' : id}')),
                if (result.syncedBillIds.length > 5)
                  Text('• ... and ${result.syncedBillIds.length - 5} more'),
              ],
              if (result.failedBillIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Failed Bills:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ...result.failedBillIds.take(3).map((id) => Text('• ${id.length > 20 ? id.substring(0, 20) + '...' : id}', style: const TextStyle(color: Colors.red))),
                if (result.failedBillIds.length > 3)
                  Text('• ... and ${result.failedBillIds.length - 3} more', style: const TextStyle(color: Colors.red)),
              ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSyncStatusIndicator() {
    if (_isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _getSyncingStatusText(),
              style: const TextStyle(
                color: primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 14, color: Colors.orange),
            SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_offlineBillsCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              '$_offlineBillsCount pending',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done, size: 14, color: primaryColor),
          SizedBox(width: 4),
          Text(
            'Synced',
            style: TextStyle(
              color: primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getSyncingStatusText() {
    switch (_currentSyncStatus) {
      case OfflineBillSyncStatus.manualSyncStarted:
        return 'Manual sync...';
      case OfflineBillSyncStatus.conflictDetected:
        return 'Resolving conflicts...';
      case OfflineBillSyncStatus.partialSync:
        return 'Partial sync...';
      default:
        return 'Syncing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.sync, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sync Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'tabfont',
                  ),
                ),
              ),
              _buildSyncStatusIndicator(),
            ],
          ),
          
          if (_offlineBillsCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$_offlineBillsCount bills pending sync',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontFamily: 'fontmain',
              ),
            ),
          ],
          
          if (_lastSyncError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: $_lastSyncError',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 11,
                        fontFamily: 'fontmain',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (_lastSyncTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last sync: ${_formatDateTime(_lastSyncTime!)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontFamily: 'fontmain',
              ),
            ),
          ],
          
          if (_offlineBillsCount > 0 && _isConnected && !_isSyncing) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _manualSync,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync Now', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
