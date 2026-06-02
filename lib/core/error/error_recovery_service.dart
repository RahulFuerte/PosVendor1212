// Dart imports:
import 'dart:async';

// Project imports:
import '../../data/datasources/remote/node_api_dao.dart';
import '../network/connection_monitor.dart';
import 'error_handling_service.dart';
import 'user_error_service.dart';

/// Service for handling error recovery workflows and automatic recovery
/// Online-only version - no SQLite or sync dependencies
class ErrorRecoveryService {
  static final ErrorRecoveryService _instance = ErrorRecoveryService._internal();
  factory ErrorRecoveryService() => _instance;
  ErrorRecoveryService._internal();

  final ErrorHandlingService _errorService = ErrorHandlingService();
  final UserErrorService _userErrorService = UserErrorService();
  final StreamController<RecoveryProgress> _progressController = StreamController<RecoveryProgress>.broadcast();

  ConnectionMonitor? _connectionMonitor;
  NodeApiDAO? _nodeApiDAO;

  bool _isInitialized = false;
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryAttempts = {};

  /// Stream that emits recovery progress updates
  Stream<RecoveryProgress> get progressStream => _progressController.stream;

  /// Initialize the error recovery service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _errorService.initialize();
      await _userErrorService.initialize();

      _connectionMonitor = ConnectionMonitor();
      _nodeApiDAO = NodeApiDAO();

      await _connectionMonitor!.initialize();
      await _nodeApiDAO!.initialize();

      _userErrorService.notificationStream.listen(_handleUserNotification);

      _isInitialized = true;
      await _errorService.logInfo('ErrorRecoveryService', 'Error recovery service initialized');
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Failed to initialize error recovery service',
        error: e,
        severity: ErrorSeverity.high,
      );
      rethrow;
    }
  }

  void _handleUserNotification(UserErrorNotification notification) {
    if (notification.autoRetry) {
      _scheduleAutoRecovery(notification);
    }
  }

  void _scheduleAutoRecovery(UserErrorNotification notification) {
    final retryKey = '${notification.type.name}_${notification.id}';
    _retryTimers[retryKey]?.cancel();
    final currentAttempts = _retryAttempts[retryKey] ?? 0;
    const maxAttempts = 3;

    if (currentAttempts >= maxAttempts) return;

    final delaySeconds = _calculateRetryDelay(currentAttempts);
    _retryTimers[retryKey] = Timer(Duration(seconds: delaySeconds), () async {
      _retryAttempts[retryKey] = currentAttempts + 1;
      await _executeAutoRecovery(notification);
    });
  }

  int _calculateRetryDelay(int attemptNumber) {
    final baseDelay = 30 * (1 << attemptNumber);
    final jitter = (baseDelay * 0.25 * (DateTime.now().millisecond / 1000)).round();
    return baseDelay + jitter;
  }

  Future<void> _executeAutoRecovery(UserErrorNotification notification) async {
    final recoveryId = 'auto_${notification.id}';

    _progressController.add(RecoveryProgress(
      id: recoveryId,
      type: notification.type,
      status: RecoveryStatus.inProgress,
      message: 'Attempting automatic recovery...',
      progress: 0.0,
    ));

    try {
      bool success = false;

      switch (notification.type) {
        case UserErrorType.networkConnection:
          success = await _recoverNetworkConnection();
          break;
        case UserErrorType.cloudServiceError:
          success = await _recoverCloudServiceError();
          break;
        default:
          success = false;
      }

      _progressController.add(RecoveryProgress(
        id: recoveryId,
        type: notification.type,
        status: success ? RecoveryStatus.completed : RecoveryStatus.failed,
        message: success ? 'Automatic recovery completed successfully' : 'Automatic recovery failed',
        progress: success ? 1.0 : 0.0,
      ));

      if (success) {
        _userErrorService.showSuccess(
          title: 'Problem Resolved',
          message: 'The issue has been automatically resolved.',
        );
        final retryKey = '${notification.type.name}_${notification.id}';
        _retryAttempts.remove(retryKey);
        _retryTimers.remove(retryKey);
      }
    } catch (e) {
      _progressController.add(RecoveryProgress(
        id: recoveryId,
        type: notification.type,
        status: RecoveryStatus.failed,
        message: 'Automatic recovery encountered an error: ${e.toString()}',
        progress: 0.0,
      ));
    }
  }

  Future<bool> _recoverNetworkConnection() async {
    try {
      return await _connectionMonitor!.checkConnectivity();
    } catch (e) {
      return false;
    }
  }

  Future<bool> _recoverCloudServiceError() async {
    try {
      await _nodeApiDAO!.initialize();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<RecoveryResult> executeRecoveryAction(
    String actionId,
    UserErrorType errorType, {
    Map<String, dynamic>? parameters,
  }) async {
    final recoveryId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

    _progressController.add(RecoveryProgress(
      id: recoveryId,
      type: errorType,
      status: RecoveryStatus.inProgress,
      message: 'Executing recovery action...',
      progress: 0.0,
    ));

    try {
      bool success = false;
      String message = '';

      switch (actionId) {
        case 'check_connection':
          success = await _connectionMonitor!.checkConnectivity();
          message = success ? 'Connection is available' : 'No connection available';
          break;
        case 'retry_operation':
          success = true;
          message = 'Please try your operation again';
          break;
        default:
          success = false;
          message = 'Unknown recovery action';
      }

      _progressController.add(RecoveryProgress(
        id: recoveryId,
        type: errorType,
        status: success ? RecoveryStatus.completed : RecoveryStatus.failed,
        message: message,
        progress: success ? 1.0 : 0.0,
      ));

      return RecoveryResult(
        success: success,
        message: message,
        actionId: actionId,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _progressController.add(RecoveryProgress(
        id: recoveryId,
        type: errorType,
        status: RecoveryStatus.failed,
        message: 'Recovery action failed: ${e.toString()}',
        progress: 0.0,
      ));

      return RecoveryResult(
        success: false,
        message: 'Recovery action failed: ${e.toString()}',
        actionId: actionId,
        timestamp: DateTime.now(),
      );
    }
  }

  RecoveryWorkflow getRecoveryWorkflow(UserErrorType errorType) {
    switch (errorType) {
      case UserErrorType.networkConnection:
        return RecoveryWorkflow(
          errorType: errorType,
          steps: [
            RecoveryStep(
              id: 'check_wifi',
              title: 'Check Wi-Fi Connection',
              description: 'Ensure your device is connected to Wi-Fi or mobile data',
              isAutomatic: false,
            ),
            RecoveryStep(
              id: 'retry_operation',
              title: 'Try Again',
              description: 'Retry the operation once connection is restored',
              isAutomatic: true,
            ),
          ],
        );
      default:
        return RecoveryWorkflow(
          errorType: errorType,
          steps: [
            RecoveryStep(
              id: 'retry',
              title: 'Try Again',
              description: 'Retry the operation that failed',
              isAutomatic: false,
            ),
          ],
        );
    }
  }

  void cancelAllRecovery() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
  }

  Map<String, dynamic> getRecoveryStatistics() {
    return {
      'activeRetryOperations': _retryTimers.length,
      'totalRetryAttempts': _retryAttempts.values.fold(0, (sum, attempts) => sum + attempts),
    };
  }

  void dispose() {
    cancelAllRecovery();
    _progressController.close();
    _userErrorService.dispose();
  }
}

/// Recovery progress information
class RecoveryProgress {
  final String id;
  final UserErrorType type;
  final RecoveryStatus status;
  final String message;
  final double progress;

  RecoveryProgress({
    required this.id,
    required this.type,
    required this.status,
    required this.message,
    required this.progress,
  });
}

/// Recovery operation status
enum RecoveryStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Result of a recovery operation
class RecoveryResult {
  final bool success;
  final String message;
  final String actionId;
  final DateTime timestamp;

  RecoveryResult({
    required this.success,
    required this.message,
    required this.actionId,
    required this.timestamp,
  });
}

/// Recovery workflow definition
class RecoveryWorkflow {
  final UserErrorType errorType;
  final List<RecoveryStep> steps;

  RecoveryWorkflow({
    required this.errorType,
    required this.steps,
  });
}

/// Individual recovery step
class RecoveryStep {
  final String id;
  final String title;
  final String description;
  final bool isAutomatic;

  RecoveryStep({
    required this.id,
    required this.title,
    required this.description,
    required this.isAutomatic,
  });
}
