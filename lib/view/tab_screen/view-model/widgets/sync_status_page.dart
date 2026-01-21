// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';

// Project imports:

import '../../../../core/network/connection_monitor.dart';
import '../../../../data/datasources/sync_manager.dart';
import '../constants/constants.dart';
import 'sync_progress_dialog.dart';

/// Comprehensive sync status page for detailed sync management
class SyncStatusPage extends StatefulWidget {
  final String adminUid;
  final String uid;

  const SyncStatusPage({
    Key? key,
    required this.adminUid,
    required this.uid,
  }) : super(key: key);

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  final SyncManager _syncManager = SyncManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();

  StreamSubscription<SyncOperationStatus>? _syncStatusSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  SyncOperationStatus _currentStatus = SyncOperationStatus.idle;
  SyncResult? _lastResult;
  bool _isConnected = false;
  Map<String, dynamic> _syncStatistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupListeners();
    _loadData();
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
            _lastResult = result;
          });
          _loadSyncStatistics();
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadConnectivityStatus(),
      _loadSyncStatistics(),
    ]);

    setState(() {
      _isLoading = false;
    });
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

  Future<void> _loadSyncStatistics() async {
    try {
      final stats = await _syncManager.getSyncStatistics();
      if (mounted) {
        setState(() {
          _syncStatistics = stats;
        });
      }
    } catch (e) {
      print('Failed to load sync statistics: $e');
    }
  }

  Future<void> _performFullSync() async {
    SyncProgressDialog.show(
      context,
      adminUid: widget.adminUid,
      onSyncCompleted: () {
        _loadSyncStatistics();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full sync completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  Future<void> _performManualSync() async {
    try {
      await _syncManager.syncPendingData();
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

  Widget _buildConnectionStatus() {
    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isConnected ? primaryColor.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? primaryColor : Colors.red,
          ),
        ),
        title: Text(
          _isConnected ? 'Online' : 'Offline',
          style: const TextStyle(
            fontFamily: 'tabfont',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _isConnected ? 'Connected to internet' : 'No internet connection',
          style: TextStyle(
            fontFamily: 'fontmain',
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          _isConnected ? Icons.check_circle : Icons.error,
          color: _isConnected ? primaryColor : Colors.red,
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (_currentStatus) {
      case SyncOperationStatus.syncing:
        statusText = 'Syncing';
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case SyncOperationStatus.retrying:
        statusText = 'Retrying';
        statusColor = Colors.orange;
        statusIcon = Icons.refresh;
        break;
      case SyncOperationStatus.completed:
        statusText = 'Completed';
        statusColor = primaryColor;
        statusIcon = Icons.check_circle;
        break;
      case SyncOperationStatus.failed:
        statusText = 'Failed';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case SyncOperationStatus.idle:
      default:
        statusText = 'Idle';
        statusColor = Colors.grey;
        statusIcon = Icons.pause_circle;
        break;
    }

    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          'Sync Status: $statusText',
          style: const TextStyle(
            fontFamily: 'tabfont',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: _lastResult?.errorMessage != null
            ? Text(
                'Error: ${_lastResult!.errorMessage}',
                style: const TextStyle(
                  color: Colors.red,
                  fontFamily: 'fontmain',
                  fontSize: 13,
                ),
              )
            : _lastResult?.success == true
                ? Text(
                    'Last sync: ${_lastResult!.itemsSynced} items',
                    style: TextStyle(
                      fontFamily: 'fontmain',
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  )
                : Text(
                    'Ready to sync',
                    style: TextStyle(
                      fontFamily: 'fontmain',
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
        trailing: _currentStatus == SyncOperationStatus.syncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSyncStatistics() {
    if (_syncStatistics.isEmpty) {
      return Container(
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
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info, color: Colors.grey),
          ),
          title: const Text(
            'Loading statistics...',
            style: TextStyle(
              fontFamily: 'tabfont',
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final pendingCount = _syncStatistics['pendingItemsCount'] ?? 0;
    final lastSyncTime = _syncStatistics['lastSyncTime'];
    final isInitialized = _syncStatistics['isInitialized'] ?? false;

    return Container(
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
          const Row(
            children: [
              Icon(Icons.analytics, color: primaryColor),
              SizedBox(width: 8),
              Text(
                'Sync Statistics',
                style: TextStyle(
                  fontFamily: 'tabfont',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow('Pending Items', pendingCount.toString(), pendingCount > 0 ? Colors.orange : primaryColor),
          _buildStatRow('Last Sync', lastSyncTime ?? 'Never', Colors.grey[700]!),
          _buildStatRow('Sync Manager', isInitialized ? 'Initialized' : 'Not initialized',
              isInitialized ? primaryColor : Colors.orange),
          _buildStatRow('Connection', _isConnected ? 'Online' : 'Offline', _isConnected ? primaryColor : Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'fontmain',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'fontmain',
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final pendingCount = _syncStatistics['pendingItemsCount'] ?? 0;
    final canSync =
        _isConnected && _currentStatus != SyncOperationStatus.syncing && _currentStatus != SyncOperationStatus.retrying;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.touch_app, color: primaryColor),
              SizedBox(width: 8),
              Text(
                'Sync Actions',
                style: TextStyle(
                  fontFamily: 'tabfont',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: canSync && pendingCount > 0 ? _performManualSync : null,
            icon: const Icon(Icons.sync),
            label: Text(
              'Sync Pending Items ($pendingCount)',
              style: const TextStyle(
                fontFamily: 'tabfont',
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: canSync ? _performFullSync : null,
            icon: const Icon(Icons.sync_alt),
            label: const Text(
              'Full Sync',
              style: TextStyle(
                fontFamily: 'tabfont',
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: primaryColor),
            label: const Text(
              'Refresh Status',
              style: TextStyle(
                fontFamily: 'tabfont',
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      drawer: MyDrawer(
        phoneNo: widget.uid,
        adminPhoneNo: widget.adminUid,
      ),
      appBar: AppBar(
        backgroundColor: white,
        elevation: 0,
        title: const Text(
          'Sync Diagnostics',
          style: TextStyle(
            color: Colors.black87,
            fontFamily: 'tabfont',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildConnectionStatus(),
                  const SizedBox(height: 12),
                  _buildSyncStatus(),
                  const SizedBox(height: 12),
                  _buildSyncStatistics(),
                  const SizedBox(height: 12),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }
}
