import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/sync_manager.dart';
import '../backend/connection_monitor.dart';

/// Comprehensive sync status widget that displays sync progress, completion, errors, and offline status
class SyncStatusWidget extends StatefulWidget {
  final String adminUid;
  final VoidCallback? onSyncCompleted;
  final VoidCallback? onRetryRequested;
  final bool showPendingCount;
  final bool showLastSyncTime;
  final bool showManualSyncButton;

  const SyncStatusWidget({
    Key? key,
    required this.adminUid,
    this.onSyncCompleted,
    this.onRetryRequested,
    this.showPendingCount = true,
    this.showLastSyncTime = true,
    this.showManualSyncButton = true,
  }) : super(key: key);

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final SyncManager _syncManager = SyncManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  
  StreamSubscription<SyncOperationStatus>? _syncStatusSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  
  SyncOperationStatus _currentStatus = SyncOperationStatus.idle;
  SyncResult? _lastSyncResult;
  bool _isConnected = false;
  int _pendingItemsCount = 0;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupListeners();
    _loadInitialData();
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _syncResultSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await _syncManager.initialize();
      await _connectionMonitor.initialize();
    } catch (e) {
      print('Failed to initialize sync services: $e');
    }
  }

  void _setupListeners() {
    // Listen to sync status changes
    _syncStatusSubscription = _syncManager.syncStatusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _currentStatus = status;
          });
        }
      },
    );

    // Listen to sync results
    _syncResultSubscription = _syncManager.syncResultStream.listen(
      (result) {
        if (mounted) {
          setState(() {
            _lastSyncResult = result;
            _lastSyncTime = result.timestamp;
          });
          
          if (result.success) {
            widget.onSyncCompleted?.call();
            _loadPendingItemsCount(); // Refresh count after successful sync
          }
          
          _showSyncResultSnackBar(result);
        }
      },
    );

    // Listen to connectivity changes
    _connectivitySubscription = _connectionMonitor.connectivityStream.listen(
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
    await _loadConnectivityStatus();
    await _loadPendingItemsCount();
    await _loadLastSyncTime();
  }

  Future<void> _loadConnectivityStatus() async {
    try {
      final isConnected = _connectionMonitor.isConnected;
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      print('Failed to load connectivity status: $e');
    }
  }

  Future<void> _loadPendingItemsCount() async {
    if (!widget.showPendingCount) return;
    
    try {
      final count = await _syncManager.getPendingSyncCount();
      if (mounted) {
        setState(() {
          _pendingItemsCount = count;
        });
      }
    } catch (e) {
      print('Failed to load pending items count: $e');
    }
  }

  Future<void> _loadLastSyncTime() async {
    if (!widget.showLastSyncTime) return;
    
    try {
      final lastSync = await _syncManager.getLastSyncTime();
      if (mounted) {
        setState(() {
          _lastSyncTime = lastSync;
        });
      }
    } catch (e) {
      print('Failed to load last sync time: $e');
    }
  }

  Future<void> _manualSync() async {
    if (_currentStatus == SyncOperationStatus.syncing || !_isConnected) return;

    try {
      await _syncManager.syncPendingData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manual sync failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _manualSync,
            ),
          ),
        );
      }
    }
  }

  void _retrySync() {
    widget.onRetryRequested?.call();
    _manualSync();
  }

  void _showSyncResultSnackBar(SyncResult result) {
    if (!mounted) return;

    final String message = result.success
        ? 'Successfully synced ${result.itemsSynced} items'
        : 'Sync failed: ${result.errorMessage}';

    final Color backgroundColor = result.success ? Colors.green : Colors.red;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: result.success ? 2 : 4),
        action: !result.success ? SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _retrySync,
        ) : null,
      ),
    );
  }

  Widget _buildSyncProgressIndicator() {
    if (_currentStatus == SyncOperationStatus.syncing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Syncing...',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_currentStatus == SyncOperationStatus.retrying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Retrying...',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildOfflineStatusIndicator() {
    if (!_isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
            const Text(
              'Offline',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSyncCompletionIndicator() {
    if (_currentStatus == SyncOperationStatus.completed && _lastSyncResult?.success == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              'Synced ${_formatDateTime(_lastSyncTime!)}',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorDisplay() {
    if (_currentStatus == SyncOperationStatus.failed && _lastSyncResult?.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Sync Failed',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _lastSyncResult!.errorMessage!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _isConnected ? _retrySync : null,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPendingSyncCount() {
    if (!widget.showPendingCount || _pendingItemsCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sync_problem,
            size: 16,
            color: Colors.amber,
          ),
          const SizedBox(width: 4),
          Text(
            '$_pendingItemsCount pending',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSyncButton() {
    if (!widget.showManualSyncButton || 
        !_isConnected || 
        _currentStatus == SyncOperationStatus.syncing ||
        _pendingItemsCount == 0) {
      return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      onPressed: _manualSync,
      icon: const Icon(Icons.sync, size: 18),
      label: const Text('Sync Now'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and main status indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sync Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    _buildSyncProgressIndicator(),
                    _buildOfflineStatusIndicator(),
                    _buildSyncCompletionIndicator(),
                    _buildPendingSyncCount(),
                  ],
                ),
              ],
            ),
            
            // Error display
            _buildErrorDisplay(),
            
            // Last sync time (if enabled and available)
            if (widget.showLastSyncTime && _lastSyncTime != null && _currentStatus != SyncOperationStatus.failed) ...[
              const SizedBox(height: 8),
              Text(
                'Last sync: ${_formatDateTime(_lastSyncTime!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
            
            // Manual sync button
            if (widget.showManualSyncButton && _pendingItemsCount > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildManualSyncButton(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}