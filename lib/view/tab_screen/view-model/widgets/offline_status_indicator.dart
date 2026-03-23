// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pos/view/home/navigation.dart';

/// Widget that displays the current offline status
class OfflineStatusIndicator extends StatefulWidget {
  final bool showWhenOnline;
  final Color? offlineColor;
  final Color? onlineColor;
  final IconData? offlineIcon;
  final IconData? onlineIcon;

  const OfflineStatusIndicator({
    super.key,
    this.showWhenOnline = false,
    this.offlineColor,
    this.onlineColor,
    this.offlineIcon,
    this.onlineIcon,
  });

  @override
  State<OfflineStatusIndicator> createState() => _OfflineStatusIndicatorState();
}

class _OfflineStatusIndicatorState extends State<OfflineStatusIndicator> {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOnline = true;
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
        _isOnline = connectivityResult != ConnectivityResult.none;
      });
    } catch (e) {
      // If connectivity check fails, assume offline to be safe
      setState(() {
        _isOnline = false;
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't show indicator when online unless explicitly requested
    if (_isOnline && !widget.showWhenOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: !_isOnline 
            ? (widget.offlineColor ?? Colors.orange.withOpacity(0.1))
            : (widget.onlineColor ?? appbar1.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !_isOnline 
              ? (widget.offlineColor ?? Colors.orange)
              : (widget.onlineColor ?? appbar1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            !_isOnline 
                ? (widget.offlineIcon ?? Icons.cloud_off)
                : (widget.onlineIcon ?? Icons.cloud_done),
            size: 16,
            color: !_isOnline 
                ? (widget.offlineColor ?? Colors.orange)
                : (widget.onlineColor ?? appbar1),
          ),
          const SizedBox(width: 4),
          MyText(
            text: !_isOnline ? 'Offline' : 'Online',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: !_isOnline 
                ? (widget.offlineColor ?? Colors.orange)
                : (widget.onlineColor ?? appbar1),
          ),
          if (!_isOnline && _pendingItemsCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: widget.offlineColor ?? Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: MyText(
                text: '$_pendingItemsCount',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
