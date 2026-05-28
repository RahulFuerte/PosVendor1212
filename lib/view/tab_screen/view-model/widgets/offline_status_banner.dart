// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enhanced banner that shows offline status and data availability
class OfflineStatusBanner extends StatefulWidget {
  final String? adminUid;
  final bool showDataStats;
  final String? customMessage;

  const OfflineStatusBanner({
    Key? key,
    this.adminUid,
    this.showDataStats = true,
    this.customMessage,
  }) : super(key: key);

  @override
  State<OfflineStatusBanner> createState() => _OfflineStatusBannerState();
}

class _OfflineStatusBannerState extends State<OfflineStatusBanner> {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOffline = false;
  final int _pendingItemsCount = 0;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _isOffline = connectivityResult == ConnectivityResult.none;
      });
    } catch (e) {
      // If connectivity check fails, assume online
      setState(() {
        _isOffline = false;
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        setState(() {
          _isOffline = result == ConnectivityResult.none;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show banner when offline
    if (!_isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade600,
            Colors.orange.shade500,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Main offline indicator
              Row(
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MyText(
                      text: widget.customMessage ?? 'You\'re offline - Data available locally',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (_pendingItemsCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MyText(
                        text: '$_pendingItemsCount pending sync',
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              // Data availability stats (if enabled)
              if (widget.showDataStats) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDataTypeIndicator('Items', Icons.restaurant_menu),
                    _buildDataTypeIndicator('Depts', Icons.category),
                    _buildDataTypeIndicator('Bills', Icons.receipt),
                    _buildDataTypeIndicator('Images', Icons.image, isAvailable: false),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTypeIndicator(String label, IconData icon, {bool isAvailable = true}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isAvailable ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.5),
          size: 14,
        ),
        const SizedBox(width: 4),
        MyText(
          text: label,
          color: isAvailable ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ],
    );
  }
}
