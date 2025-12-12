import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/user_error_service.dart';
import '../backend/error_recovery_service.dart';

/// Widget that displays error notifications to users with recovery options
class ErrorNotificationWidget extends StatefulWidget {
  final UserErrorService userErrorService;
  final ErrorRecoveryService recoveryService;

  const ErrorNotificationWidget({
    Key? key,
    required this.userErrorService,
    required this.recoveryService,
  }) : super(key: key);

  @override
  State<ErrorNotificationWidget> createState() => _ErrorNotificationWidgetState();
}

class _ErrorNotificationWidgetState extends State<ErrorNotificationWidget> {
  StreamSubscription<UserErrorNotification>? _notificationSubscription;
  final List<UserErrorNotification> _activeNotifications = [];

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _notificationSubscription = widget.userErrorService.notificationStream.listen(
      (notification) {
        if (mounted) {
          setState(() {
            // Remove old notifications of the same type to avoid spam
            _activeNotifications.removeWhere((n) => n.type == notification.type);
            _activeNotifications.add(notification);
          });

          // Auto-dismiss success notifications after 3 seconds
          if (notification.severity == UserNotificationSeverity.success) {
            Timer(const Duration(seconds: 3), () {
              if (mounted) {
                _dismissNotification(notification.id);
              }
            });
          }
        }
      },
    );
  }

  void _dismissNotification(String notificationId) {
    setState(() {
      _activeNotifications.removeWhere((n) => n.id == notificationId);
    });
  }

  void _executeRecoveryAction(UserErrorNotification notification, UserRecoveryAction action) async {
    try {
      final result = await widget.recoveryService.executeRecoveryAction(
        action.id,
        notification.type,
      );

      if (result.success) {
        _dismissNotification(notification.id);
        
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show failure feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recovery failed: ${result.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recovery action failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _getNotificationColor(UserNotificationSeverity severity) {
    switch (severity) {
      case UserNotificationSeverity.success:
        return Colors.green;
      case UserNotificationSeverity.info:
        return Colors.blue;
      case UserNotificationSeverity.warning:
        return Colors.orange;
      case UserNotificationSeverity.error:
        return Colors.red;
    }
  }

  IconData _getNotificationIcon(UserNotificationSeverity severity) {
    switch (severity) {
      case UserNotificationSeverity.success:
        return Icons.check_circle;
      case UserNotificationSeverity.info:
        return Icons.info;
      case UserNotificationSeverity.warning:
        return Icons.warning;
      case UserNotificationSeverity.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out old notifications
    final relevantNotifications = _activeNotifications
        .where((n) => n.isRelevant)
        .toList();

    if (relevantNotifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Column(
        children: relevantNotifications.map((notification) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.severity).withOpacity(0.1),
                  border: Border.all(
                    color: _getNotificationColor(notification.severity),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getNotificationIcon(notification.severity),
                          color: _getNotificationColor(notification.severity),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getNotificationColor(notification.severity),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (notification.canDismiss)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _dismissNotification(notification.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    if (notification.recoveryActions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: notification.recoveryActions.map((action) {
                          return ElevatedButton(
                            onPressed: () => _executeRecoveryAction(notification, action),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getNotificationColor(notification.severity),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              action.title,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}

/// Overlay widget that can be used to show error notifications on top of any screen
class ErrorNotificationOverlay extends StatelessWidget {
  final Widget child;
  final UserErrorService userErrorService;
  final ErrorRecoveryService recoveryService;

  const ErrorNotificationOverlay({
    Key? key,
    required this.child,
    required this.userErrorService,
    required this.recoveryService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ErrorNotificationWidget(
          userErrorService: userErrorService,
          recoveryService: recoveryService,
        ),
      ],
    );
  }
}

/// Simple error banner that can be embedded in screens
class ErrorBannerWidget extends StatefulWidget {
  final UserErrorService userErrorService;
  final ErrorRecoveryService recoveryService;

  const ErrorBannerWidget({
    Key? key,
    required this.userErrorService,
    required this.recoveryService,
  }) : super(key: key);

  @override
  State<ErrorBannerWidget> createState() => _ErrorBannerWidgetState();
}

class _ErrorBannerWidgetState extends State<ErrorBannerWidget> {
  StreamSubscription<UserErrorNotification>? _notificationSubscription;
  UserErrorNotification? _currentNotification;

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _notificationSubscription = widget.userErrorService.notificationStream.listen(
      (notification) {
        if (mounted && notification.severity != UserNotificationSeverity.success) {
          setState(() {
            _currentNotification = notification;
          });

          // Auto-dismiss after 10 seconds for non-critical errors
          if (notification.canDismiss && notification.severity != UserNotificationSeverity.error) {
            Timer(const Duration(seconds: 10), () {
              if (mounted && _currentNotification?.id == notification.id) {
                setState(() {
                  _currentNotification = null;
                });
              }
            });
          }
        }
      },
    );
  }

  void _dismissNotification() {
    setState(() {
      _currentNotification = null;
    });
  }

  Color _getBannerColor(UserNotificationSeverity severity) {
    switch (severity) {
      case UserNotificationSeverity.info:
        return Colors.blue.shade100;
      case UserNotificationSeverity.warning:
        return Colors.orange.shade100;
      case UserNotificationSeverity.error:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getTextColor(UserNotificationSeverity severity) {
    switch (severity) {
      case UserNotificationSeverity.info:
        return Colors.blue.shade800;
      case UserNotificationSeverity.warning:
        return Colors.orange.shade800;
      case UserNotificationSeverity.error:
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNotification == null || !_currentNotification!.isRelevant) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBannerColor(_currentNotification!.severity),
        border: Border(
          left: BorderSide(
            color: _getTextColor(_currentNotification!.severity),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _currentNotification!.severity == UserNotificationSeverity.error
                ? Icons.error_outline
                : _currentNotification!.severity == UserNotificationSeverity.warning
                    ? Icons.warning_amber_outlined
                    : Icons.info_outline,
            color: _getTextColor(_currentNotification!.severity),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentNotification!.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getTextColor(_currentNotification!.severity),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentNotification!.message,
                  style: TextStyle(
                    color: _getTextColor(_currentNotification!.severity),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_currentNotification!.canDismiss)
            IconButton(
              icon: Icon(
                Icons.close,
                color: _getTextColor(_currentNotification!.severity),
                size: 18,
              ),
              onPressed: _dismissNotification,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}