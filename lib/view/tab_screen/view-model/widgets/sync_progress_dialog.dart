import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/sync_manager.dart';

/// Dialog that shows detailed sync progress with real-time updates
class SyncProgressDialog extends StatefulWidget {
  final String adminUid;
  final VoidCallback? onSyncCompleted;
  final VoidCallback? onSyncCancelled;

  const SyncProgressDialog({
    Key? key,
    required this.adminUid,
    this.onSyncCompleted,
    this.onSyncCancelled,
  }) : super(key: key);

  /// Show the sync progress dialog
  static Future<void> show(
    BuildContext context, {
    required String adminUid,
    VoidCallback? onSyncCompleted,
    VoidCallback? onSyncCancelled,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SyncProgressDialog(
          adminUid: adminUid,
          onSyncCompleted: onSyncCompleted,
          onSyncCancelled: onSyncCancelled,
        );
      },
    );
  }

  @override
  State<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<SyncProgressDialog>
    with SingleTickerProviderStateMixin {
  final SyncManager _syncManager = SyncManager();
  
  StreamSubscription<SyncOperationStatus>? _syncStatusSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;
  
  SyncOperationStatus _currentStatus = SyncOperationStatus.idle;
  SyncResult? _lastResult;
  int _itemsSynced = 0;
  String? _currentOperation;
  
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeServices();
    _setupListeners();
    _startSync();
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _syncResultSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServices() async {
    try {
      await _syncManager.initialize();
    } catch (e) {
      print('Failed to initialize sync manager: $e');
    }
  }

  void _setupListeners() {
    // Listen to sync status changes
    _syncStatusSubscription = _syncManager.syncStatusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _currentStatus = status;
            _currentOperation = _getOperationText(status);
          });
          
          // Control animation based on sync status
          if (status == SyncOperationStatus.syncing || status == SyncOperationStatus.retrying) {
            _animationController.repeat();
          } else {
            _animationController.stop();
          }
        }
      },
    );

    // Listen to sync results
    _syncResultSubscription = _syncManager.syncResultStream.listen(
      (result) {
        if (mounted) {
          setState(() {
            _lastResult = result;
            _itemsSynced = result.itemsSynced;
          });
          
          // Auto-close dialog on completion or show error
          if (result.success) {
            _animationController.forward().then((_) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  Navigator.of(context).pop();
                  widget.onSyncCompleted?.call();
                }
              });
            });
          }
        }
      },
    );
  }

  Future<void> _startSync() async {
    try {
      await _syncManager.syncPendingData();
    } catch (e) {
      print('Failed to start sync: $e');
    }
  }

  void _cancelSync() {
    _syncManager.cancelSync();
    Navigator.of(context).pop();
    widget.onSyncCancelled?.call();
  }

  void _retrySync() {
    setState(() {
      _lastResult = null;
      _itemsSynced = 0;
    });
    _startSync();
  }

  String _getOperationText(SyncOperationStatus status) {
    switch (status) {
      case SyncOperationStatus.syncing:
        return 'Syncing data to cloud...';
      case SyncOperationStatus.retrying:
        return 'Retrying sync operation...';
      case SyncOperationStatus.completed:
        return 'Sync completed successfully';
      case SyncOperationStatus.failed:
        return 'Sync operation failed';
      case SyncOperationStatus.idle:
      default:
        return 'Preparing to sync...';
    }
  }

  Widget _buildProgressIndicator() {
    if (_currentStatus == SyncOperationStatus.completed && _lastResult?.success == true) {
      return AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return CircularProgressIndicator(
            value: _progressAnimation.value,
            strokeWidth: 4,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            backgroundColor: Colors.green[100],
          );
        },
      );
    }

    if (_currentStatus == SyncOperationStatus.failed) {
      return const Icon(
        Icons.error,
        size: 48,
        color: Colors.red,
      );
    }

    return const CircularProgressIndicator(
      strokeWidth: 4,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
    );
  }

  Widget _buildStatusText() {
    return Column(
      children: [
        Text(
          _currentOperation ?? 'Initializing...',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        if (_itemsSynced > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$_itemsSynced items synced',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (_lastResult?.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _lastResult!.errorMessage!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_currentStatus == SyncOperationStatus.failed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: _cancelSync,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _retrySync,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_currentStatus == SyncOperationStatus.syncing || _currentStatus == SyncOperationStatus.retrying) {
      return TextButton(
        onPressed: _cancelSync,
        child: const Text('Cancel'),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button during sync
        return _currentStatus != SyncOperationStatus.syncing && 
               _currentStatus != SyncOperationStatus.retrying;
      },
      child: AlertDialog(
        title: const Text(
          'Sync Progress',
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              _buildProgressIndicator(),
              const SizedBox(height: 24),
              _buildStatusText(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          _buildActionButtons(),
        ],
      ),
    );
  }
}