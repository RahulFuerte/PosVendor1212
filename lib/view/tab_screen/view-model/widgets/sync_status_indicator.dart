// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

import '../../../../core/network/connection_monitor.dart';
import '../../../../data/datasources/sync_manager.dart';

// Project imports:


/// Compact sync status indicator for use in app bars and navigation
class SyncStatusIndicator extends StatefulWidget {
  final VoidCallback? onTap;
  final bool showBadge;
  final double iconSize;

  const SyncStatusIndicator({
    Key? key,
    this.onTap,
    this.showBadge = true,
    this.iconSize = 24.0,
  }) : super(key: key);

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  final SyncManager _syncManager = SyncManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  
  StreamSubscription<SyncOperationStatus>? _syncStatusSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  
  SyncOperationStatus _currentStatus = SyncOperationStatus.idle;
  bool _isConnected = false;
  int _pendingItemsCount = 0;
  
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeServices();
    _setupListeners();
    _loadInitialData();
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
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
          
          // Control animation based on sync status
          if (status == SyncOperationStatus.syncing || status == SyncOperationStatus.retrying) {
            _animationController.repeat();
          } else {
            _animationController.stop();
          }
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

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
      case SyncOperationStatus.retrying:
        return Icons.sync;
      case SyncOperationStatus.completed:
        return _isConnected ? Icons.cloud_done : Icons.cloud_off;
      case SyncOperationStatus.failed:
        return Icons.sync_problem;
      case SyncOperationStatus.idle:
      default:
        if (!_isConnected) {
          return Icons.cloud_off;
        } else if (_pendingItemsCount > 0) {
          return Icons.sync_problem;
        } else {
          return Icons.cloud_done;
        }
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
        return Colors.blue;
      case SyncOperationStatus.retrying:
        return Colors.orange;
      case SyncOperationStatus.completed:
        return _isConnected ? Colors.green : Colors.orange;
      case SyncOperationStatus.failed:
        return Colors.red;
      case SyncOperationStatus.idle:
      default:
        if (!_isConnected) {
          return Colors.orange;
        } else if (_pendingItemsCount > 0) {
          return Colors.amber;
        } else {
          return Colors.green;
        }
    }
  }

  String _getTooltipText() {
    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
        return 'Syncing data...';
      case SyncOperationStatus.retrying:
        return 'Retrying sync...';
      case SyncOperationStatus.completed:
        return _isConnected ? 'Data synced' : 'Offline mode';
      case SyncOperationStatus.failed:
        return 'Sync failed - tap to retry';
      case SyncOperationStatus.idle:
      default:
        if (!_isConnected) {
          return 'Offline mode';
        } else if (_pendingItemsCount > 0) {
          return '$_pendingItemsCount items pending sync';
        } else {
          return 'All data synced';
        }
    }
  }

  Widget _buildBadge() {
    if (!widget.showBadge || _pendingItemsCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: MyText(
          text: _pendingItemsCount > 99 ? '99+' : _pendingItemsCount.toString(),
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltipText(),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: (_currentStatus == SyncOperationStatus.syncing || 
                           _currentStatus == SyncOperationStatus.retrying)
                        ? _rotationAnimation.value * 2.0 * 3.14159
                        : 0.0,
                    child: Icon(
                      _getStatusIcon(),
                      size: widget.iconSize,
                      color: _getStatusColor(),
                    ),
                  );
                },
              ),
              _buildBadge(),
            ],
          ),
        ),
      ),
    );
  }
}
