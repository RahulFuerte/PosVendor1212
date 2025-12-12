import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/sync_manager.dart';
import '../backend/connection_monitor.dart';
import 'sync_progress_dialog.dart';

/// Comprehensive sync status page for detailed sync management
class SyncStatusPage extends StatefulWidget {
  final String adminUid;

  const SyncStatusPage({
    Key? key,
    required this.adminUid,
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
    return Card(
      child: ListTile(
        leading: Icon(
          _isConnected ? Icons.wifi : Icons.wifi_off,
          color: _isConnected ? Colors.green : Colors.red,
        ),
        title: Text(_isConnected ? 'Online' : 'Offline'),
        subtitle: Text(
          _isConnected 
              ? 'Connected to internet' 
              : 'No internet connection',
        ),
        trailing: _isConnected 
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.error, color: Colors.red),
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
        statusColor = Colors.green;
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

    return Card(
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text('Sync Status: $statusText'),
        subtitle: _lastResult?.errorMessage != null
            ? Text(
                'Error: ${_lastResult!.errorMessage}',
                style: const TextStyle(color: Colors.red),
              )
            : _lastResult?.success == true
                ? Text('Last sync: ${_lastResult!.itemsSynced} items')
                : const Text('Ready to sync'),
        trailing: _currentStatus == SyncOperationStatus.syncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  Widget _buildSyncStatistics() {
    if (_syncStatistics.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info),
          title: Text('Loading statistics...'),
        ),
      );
    }

    final pendingCount = _syncStatistics['pendingItemsCount'] ?? 0;
    final lastSyncTime = _syncStatistics['lastSyncTime'];
    final isInitialized = _syncStatistics['isInitialized'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Pending Items', pendingCount.toString()),
            _buildStatRow('Last Sync', lastSyncTime ?? 'Never'),
            _buildStatRow('Sync Manager', isInitialized ? 'Initialized' : 'Not initialized'),
            _buildStatRow('Connection', _isConnected ? 'Online' : 'Offline'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final pendingCount = _syncStatistics['pendingItemsCount'] ?? 0;
    final canSync = _isConnected && 
                   _currentStatus != SyncOperationStatus.syncing &&
                   _currentStatus != SyncOperationStatus.retrying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sync Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: canSync && pendingCount > 0 ? _performManualSync : null,
              icon: const Icon(Icons.sync),
              label: Text('Sync Pending Items ($pendingCount)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: canSync ? _performFullSync : null,
              icon: const Icon(Icons.sync_alt),
              label: const Text('Full Sync'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        backgroundColor: Colors.blue[50],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildConnectionStatus(),
                  const SizedBox(height: 8),
                  _buildSyncStatus(),
                  const SizedBox(height: 8),
                  _buildSyncStatistics(),
                  const SizedBox(height: 8),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }
}