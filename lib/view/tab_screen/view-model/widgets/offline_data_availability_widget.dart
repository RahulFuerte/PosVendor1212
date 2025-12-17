import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../backend/complete_offline_data_manager.dart';
import '../backend/connection_monitor.dart';

/// Widget that displays offline data availability status
class OfflineDataAvailabilityWidget extends StatefulWidget {
  final String adminUid;
  final bool showDetails;
  final VoidCallback? onRefresh;

  const OfflineDataAvailabilityWidget({
    Key? key,
    required this.adminUid,
    this.showDetails = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<OfflineDataAvailabilityWidget> createState() => _OfflineDataAvailabilityWidgetState();
}

class _OfflineDataAvailabilityWidgetState extends State<OfflineDataAvailabilityWidget> {
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  
  Map<String, dynamic>? _availabilityData;
  bool _isLoading = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initializeAndCheck();
    _listenToConnectivity();
  }

  Future<void> _initializeAndCheck() async {
    await _checkDataAvailability();
  }

  void _listenToConnectivity() {
    _connectionMonitor.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOffline = !isConnected;
        });
      }
    });
  }

  Future<void> _checkDataAvailability() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _offlineDataManager.initialize();
      final availability = await _offlineDataManager.checkOfflineDataAvailability(widget.adminUid);
      final stats = await _offlineDataManager.getOfflineDataStatistics(widget.adminUid);
      
      if (mounted) {
        setState(() {
          _availabilityData = {
            'availability': availability,
            'stats': stats,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error checking data availability: $e', name: 'OfflineDataAvailabilityWidget');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _checkDataAvailability();
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Checking offline data availability...'),
            ],
          ),
        ),
      );
    }

    if (_availabilityData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Text('Unable to check offline data availability'),
            ],
          ),
        ),
      );
    }

    final availability = _availabilityData!['availability'] as Map<String, bool>;
    final stats = _availabilityData!['stats'] as Map<String, dynamic>;

    // Calculate overall availability score
    final availableCount = availability.values.where((v) => v).length;
    final totalCount = availability.length;
    final availabilityScore = totalCount > 0 ? (availableCount / totalCount) : 0.0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (availabilityScore >= 0.8) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Excellent';
    } else if (availabilityScore >= 0.6) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Good';
    } else if (availabilityScore >= 0.3) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Limited';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Poor';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _isOffline ? Icons.cloud_off : Icons.cloud_done,
                  color: _isOffline ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOffline ? 'Offline Mode' : 'Online Mode',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshData,
                  tooltip: 'Refresh data availability',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Overall Status
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Data Availability: $statusText',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${(availabilityScore * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            if (widget.showDetails) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Detailed Availability
              _buildDataTypeRow('Food Items', availability['food_items'] ?? false, stats['food_items_count'] ?? 0),
              _buildDataTypeRow('Departments', availability['departments'] ?? false, stats['departments_count'] ?? 0),
              _buildDataTypeRow('Bills', availability['bills'] ?? false, stats['bills_count'] ?? 0),
              _buildDataTypeRow('Images', availability['images'] ?? false, stats['cached_images_count'] ?? 0),

              if (stats['pending_sync_count'] != null && stats['pending_sync_count'] > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${stats['pending_sync_count']} items pending sync',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Quick Actions (only show when offline)
            if (_isOffline && availabilityScore < 0.8) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showDataPreloadDialog(context),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Improve Offline Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataTypeRow(String label, bool isAvailable, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.cancel,
            color: isAvailable ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDataPreloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Improve Offline Access'),
        content: const Text(
          'When you\'re back online, the app will automatically download and cache more data for better offline access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}