import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/sync_manager.dart';
import '../backend/connection_monitor.dart';

/// Banner widget that displays sync status at the top of screens
class SyncStatusBanner extends StatefulWidget {
  final String adminUid;
  final VoidCallback? onTap;
  final bool showOnlyWhenRelevant;
  final Duration autoHideDuration;

  const SyncStatusBanner({
    Key? key,
    required this.adminUid,
    this.onTap,
    this.showOnlyWhenRelevant = true,
    this.autoHideDuration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner>
    with SingleTickerProviderStateMixin {
  final SyncManager _syncManager = SyncManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  
  StreamSubscription<SyncOperationStatus>? _syncStatusSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  
  SyncOperationStatus _currentStatus = SyncOperationStatus.idle;
  SyncResult? _lastResult;
  bool _isConnected = false;
  int _pendingItemsCount = 0;
  bool _isVisible = false;
  Timer? _autoHideTimer;
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

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
    _syncResultSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _autoHideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
          _updateVisibility();
        }
      },
    );

    // Listen to sync results
    _syncResultSubscription = _syncManager.syncResultStream.listen(
      (result) {
        if (mounted) {
          setState(() {
            _lastResult = result;
          });
          _updateVisibility();
          
          // Auto-hide success messages
          if (result.success) {
            _scheduleAutoHide();
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
          _updateVisibility();
        }
      },
    );
  }

  Future<void> _loadInitialData() async {
    await _loadConnectivityStatus();
    await _loadPendingItemsCount();
    _updateVisibility();
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

  void _updateVisibility() {
    final shouldShow = _shouldShowBanner();
    
    if (shouldShow && !_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _animationController.forward();
    } else if (!shouldShow && _isVisible) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  bool _shouldShowBanner() {
    if (!widget.showOnlyWhenRelevant) {
      return true;
    }

    // Show banner for important states
    return _currentStatus == SyncOperationStatus.syncing ||
           _currentStatus == SyncOperationStatus.retrying ||
           _currentStatus == SyncOperationStatus.failed ||
           (!_isConnected && _pendingItemsCount > 0) ||
           (_currentStatus == SyncOperationStatus.completed && _lastResult?.success == true);
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(widget.autoHideDuration, () {
      if (mounted && _currentStatus == SyncOperationStatus.completed) {
        _updateVisibility();
      }
    });
  }

  Color _getBannerColor() {
    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
      case SyncOperationStatus.retrying:
        return Colors.blue;
      case SyncOperationStatus.completed:
        return Colors.green;
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

  IconData _getBannerIcon() {
    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
      case SyncOperationStatus.retrying:
        return Icons.sync;
      case SyncOperationStatus.completed:
        return Icons.check_circle;
      case SyncOperationStatus.failed:
        return Icons.error;
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

  String _getBannerText() {
    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
        return 'Syncing data...';
      case SyncOperationStatus.retrying:
        return 'Retrying sync...';
      case SyncOperationStatus.completed:
        if (_lastResult?.success == true) {
          return 'Sync completed - ${_lastResult!.itemsSynced} items synced';
        }
        return 'Sync completed';
      case SyncOperationStatus.failed:
        return 'Sync failed: ${_lastResult?.errorMessage ?? 'Unknown error'}';
      case SyncOperationStatus.idle:
      default:
        if (!_isConnected) {
          return 'Working offline - $_pendingItemsCount items pending sync';
        } else if (_pendingItemsCount > 0) {
          return '$_pendingItemsCount items pending sync';
        } else {
          return 'All data synced';
        }
    }
  }

  Widget _buildBannerContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _getBannerColor(),
      child: Row(
        children: [
          if (_currentStatus == SyncOperationStatus.syncing || _currentStatus == SyncOperationStatus.retrying)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              _getBannerIcon(),
              color: Colors.white,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getBannerText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_currentStatus == SyncOperationStatus.failed) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                await _syncManager.syncPendingData();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text('Retry'),
            ),
          ],
          if (widget.onTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onTap,
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 60),
          child: GestureDetector(
            onTap: widget.onTap,
            child: _buildBannerContent(),
          ),
        );
      },
    );
  }
}