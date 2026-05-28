// Dart imports:
import 'dart:async';

// Project imports:
import 'error_handling_service.dart';

/// Service for providing user-friendly error messages and recovery workflows
class UserErrorService {
  static final UserErrorService _instance = UserErrorService._internal();
  factory UserErrorService() => _instance;
  UserErrorService._internal();

  final ErrorHandlingService _errorService = ErrorHandlingService();
  final StreamController<UserErrorNotification> _notificationController = 
      StreamController<UserErrorNotification>.broadcast();

  /// Stream that emits user error notifications
  Stream<UserErrorNotification> get notificationStream => _notificationController.stream;

  /// Initialize the user error service
  Future<void> initialize() async {
    await _errorService.initialize();
    
    // Listen to error logs and convert to user notifications
    _errorService.logStream.listen(_handleLogEntry);
  }

  /// Handle log entries and create user notifications for critical errors
  void _handleLogEntry(LogEntry logEntry) {
    // Only create notifications for warnings and errors
    if (logEntry.level.index < LogLevel.warning.index) return;

    final notification = _createUserNotification(logEntry);
    if (notification != null) {
      _notificationController.add(notification);
    }
  }

  /// Create user notification from log entry
  UserErrorNotification? _createUserNotification(LogEntry logEntry) {
    final errorType = _categorizeError(logEntry);
    if (errorType == null) return null;

    return UserErrorNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: errorType,
      title: _getErrorTitle(errorType),
      message: _getErrorMessage(errorType, logEntry),
      severity: _mapSeverity(logEntry.level),
      recoveryActions: _getRecoveryActions(errorType, logEntry),
      timestamp: logEntry.timestamp,
      canDismiss: errorType != UserErrorType.criticalDataLoss,
      autoRetry: _shouldAutoRetry(errorType),
    );
  }

  /// Categorize error based on component and message
  UserErrorType? _categorizeError(LogEntry logEntry) {
    final component = logEntry.component.toLowerCase();
    final message = logEntry.message.toLowerCase();

    // Network-related errors
    if (message.contains('no internet') || message.contains('connection')) {
      return UserErrorType.networkConnection;
    }

    // Sync-related errors
    if (component.contains('sync') || message.contains('sync')) {
      if (message.contains('conflict')) {
        return UserErrorType.syncConflict;
      } else if (message.contains('failed') || message.contains('error')) {
        return UserErrorType.syncFailure;
      }
    }

    // Database-related errors
    if (component.contains('sqlite') || component.contains('database')) {
      if (message.contains('corruption')) {
        return UserErrorType.databaseCorruption;
      } else if (message.contains('backup')) {
        return UserErrorType.backupFailure;
      } else {
        return UserErrorType.databaseError;
      }
    }

    // Firebase-related errors
    if (component.contains('firebase') || message.contains('firebase')) {
      if (message.contains('auth')) {
        return UserErrorType.authenticationError;
      } else if (message.contains('permission')) {
        return UserErrorType.permissionError;
      } else {
        return UserErrorType.cloudServiceError;
      }
    }

    // Storage-related errors
    if (message.contains('storage') || message.contains('disk space')) {
      return UserErrorType.storageError;
    }

    // Data integrity errors
    if (message.contains('integrity') || message.contains('validation')) {
      return UserErrorType.dataIntegrityError;
    }

    // Image-related errors
    if (message.contains('image') || message.contains('blob')) {
      return UserErrorType.imageError;
    }

    // Only create notifications for errors, not warnings
    if (logEntry.level == LogLevel.error) {
      return UserErrorType.generalError;
    }

    return null;
  }

  /// Get user-friendly error title
  String _getErrorTitle(UserErrorType errorType) {
    switch (errorType) {
      case UserErrorType.networkConnection:
        return 'Connection Problem';
      case UserErrorType.syncFailure:
        return 'Sync Failed';
      case UserErrorType.syncConflict:
        return 'Data Conflict Resolved';
      case UserErrorType.databaseError:
        return 'Database Issue';
      case UserErrorType.databaseCorruption:
        return 'Data Recovery Needed';
      case UserErrorType.backupFailure:
        return 'Backup Failed';
      case UserErrorType.authenticationError:
        return 'Authentication Required';
      case UserErrorType.permissionError:
        return 'Permission Denied';
      case UserErrorType.cloudServiceError:
        return 'Cloud Service Issue';
      case UserErrorType.storageError:
        return 'Storage Problem';
      case UserErrorType.dataIntegrityError:
        return 'Data Validation Issue';
      case UserErrorType.imageError:
        return 'Image Loading Problem';
      case UserErrorType.criticalDataLoss:
        return 'Critical: Data Loss Risk';
      case UserErrorType.generalError:
        return 'Something Went Wrong';
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(UserErrorType errorType, LogEntry logEntry) {
    switch (errorType) {
      case UserErrorType.networkConnection:
        return 'Unable to connect to the internet. Your data is being saved locally and will sync automatically when connection is restored.';
      
      case UserErrorType.syncFailure:
        return 'Failed to sync your data to the cloud. Don\'t worry - your data is safe locally. We\'ll keep trying to sync automatically.';
      
      case UserErrorType.syncConflict:
        return 'Some data was updated on multiple devices. We\'ve automatically resolved the conflicts by keeping the most recent changes.';
      
      case UserErrorType.databaseError:
        return 'There was a problem with the local database. Your recent changes might not be saved. Please try the operation again.';
      
      case UserErrorType.databaseCorruption:
        return 'Data corruption was detected. We\'re attempting to recover your data automatically from the cloud backup.';
      
      case UserErrorType.backupFailure:
        return 'Unable to create a backup of your data. This won\'t affect normal operation, but we recommend checking your device storage.';
      
      case UserErrorType.authenticationError:
        return 'Your session has expired. Please sign in again to continue syncing your data to the cloud.';
      
      case UserErrorType.permissionError:
        return 'Permission denied while accessing cloud services. Please check your account permissions or contact support.';
      
      case UserErrorType.cloudServiceError:
        return 'The cloud service is temporarily unavailable. Your data is being saved locally and will sync when the service is restored.';
      
      case UserErrorType.storageError:
        return 'Your device is running low on storage space. Please free up some space to ensure proper operation.';
      
      case UserErrorType.dataIntegrityError:
        return 'Some data validation issues were found. We\'ve fixed what we can automatically, but please review your recent changes.';
      
      case UserErrorType.imageError:
        return 'Unable to load some images. They will be downloaded automatically when internet connection is available.';
      
      case UserErrorType.criticalDataLoss:
        return 'Critical error: There\'s a risk of data loss. Please contact support immediately and avoid making changes until this is resolved.';
      
      case UserErrorType.generalError:
        return logEntry.userFriendlyMessage;
    }
  }

  /// Map log level to user notification severity
  UserNotificationSeverity _mapSeverity(LogLevel logLevel) {
    switch (logLevel) {
      case LogLevel.warning:
        return UserNotificationSeverity.warning;
      case LogLevel.error:
        return UserNotificationSeverity.error;
      default:
        return UserNotificationSeverity.info;
    }
  }

  /// Get recovery actions for error type
  List<UserRecoveryAction> _getRecoveryActions(UserErrorType errorType, LogEntry logEntry) {
    switch (errorType) {
      case UserErrorType.networkConnection:
        return [
          UserRecoveryAction(
            id: 'check_connection',
            title: 'Check Connection',
            description: 'Verify your internet connection and try again',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'retry_sync',
            title: 'Retry Sync',
            description: 'Manually retry syncing your data',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.syncFailure:
        return [
          UserRecoveryAction(
            id: 'retry_sync',
            title: 'Retry Now',
            description: 'Try syncing again immediately',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'check_connection',
            title: 'Check Connection',
            description: 'Verify your internet connection',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.syncConflict:
        return [
          UserRecoveryAction(
            id: 'view_changes',
            title: 'View Changes',
            description: 'See what changes were made during conflict resolution',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.databaseError:
        return [
          UserRecoveryAction(
            id: 'retry_operation',
            title: 'Try Again',
            description: 'Retry the last operation',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'restart_app',
            title: 'Restart App',
            description: 'Close and reopen the app to reset the database connection',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.databaseCorruption:
        return [
          UserRecoveryAction(
            id: 'auto_recovery',
            title: 'Auto Recovery',
            description: 'Automatically recover data from cloud backup',
            isAutomatic: true,
          ),
          UserRecoveryAction(
            id: 'manual_recovery',
            title: 'Manual Recovery',
            description: 'Choose a specific backup to restore from',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.backupFailure:
        return [
          UserRecoveryAction(
            id: 'check_storage',
            title: 'Check Storage',
            description: 'Free up device storage space',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'retry_backup',
            title: 'Retry Backup',
            description: 'Try creating backup again',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.authenticationError:
        return [
          UserRecoveryAction(
            id: 'sign_in',
            title: 'Sign In',
            description: 'Sign in to your account again',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.storageError:
        return [
          UserRecoveryAction(
            id: 'free_storage',
            title: 'Free Storage',
            description: 'Delete unnecessary files to free up space',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'clear_cache',
            title: 'Clear Cache',
            description: 'Clear app cache to free up space',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.imageError:
        return [
          UserRecoveryAction(
            id: 'retry_download',
            title: 'Retry Download',
            description: 'Try downloading images again',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'clear_image_cache',
            title: 'Clear Image Cache',
            description: 'Clear cached images and download fresh copies',
            isAutomatic: false,
          ),
        ];

      case UserErrorType.criticalDataLoss:
        return [
          UserRecoveryAction(
            id: 'contact_support',
            title: 'Contact Support',
            description: 'Get immediate help from technical support',
            isAutomatic: false,
          ),
          UserRecoveryAction(
            id: 'emergency_backup',
            title: 'Emergency Backup',
            description: 'Create an emergency backup of current data',
            isAutomatic: false,
          ),
        ];

      default:
        return [
          UserRecoveryAction(
            id: 'retry',
            title: 'Try Again',
            description: 'Retry the operation',
            isAutomatic: false,
          ),
        ];
    }
  }

  /// Check if error type should auto-retry
  bool _shouldAutoRetry(UserErrorType errorType) {
    switch (errorType) {
      case UserErrorType.networkConnection:
      case UserErrorType.syncFailure:
      case UserErrorType.cloudServiceError:
        return true;
      default:
        return false;
    }
  }

  /// Show a custom error notification
  void showError({
    required String title,
    required String message,
    UserNotificationSeverity severity = UserNotificationSeverity.error,
    List<UserRecoveryAction>? recoveryActions,
    bool canDismiss = true,
  }) {
    final notification = UserErrorNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: UserErrorType.generalError,
      title: title,
      message: message,
      severity: severity,
      recoveryActions: recoveryActions ?? [],
      timestamp: DateTime.now(),
      canDismiss: canDismiss,
      autoRetry: false,
    );

    _notificationController.add(notification);
  }

  /// Show a success notification
  void showSuccess({
    required String title,
    required String message,
  }) {
    final notification = UserErrorNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: UserErrorType.generalError,
      title: title,
      message: message,
      severity: UserNotificationSeverity.success,
      recoveryActions: [],
      timestamp: DateTime.now(),
      canDismiss: true,
      autoRetry: false,
    );

    _notificationController.add(notification);
  }

  /// Show a warning notification
  void showWarning({
    required String title,
    required String message,
    List<UserRecoveryAction>? recoveryActions,
  }) {
    final notification = UserErrorNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: UserErrorType.generalError,
      title: title,
      message: message,
      severity: UserNotificationSeverity.warning,
      recoveryActions: recoveryActions ?? [],
      timestamp: DateTime.now(),
      canDismiss: true,
      autoRetry: false,
    );

    _notificationController.add(notification);
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
  }
}

/// Types of user errors
enum UserErrorType {
  networkConnection,
  syncFailure,
  syncConflict,
  databaseError,
  databaseCorruption,
  backupFailure,
  authenticationError,
  permissionError,
  cloudServiceError,
  storageError,
  dataIntegrityError,
  imageError,
  criticalDataLoss,
  generalError,
}

/// User notification severity levels
enum UserNotificationSeverity {
  info,
  success,
  warning,
  error,
}

/// User-friendly recovery action
class UserRecoveryAction {
  final String id;
  final String title;
  final String description;
  final bool isAutomatic;

  UserRecoveryAction({
    required this.id,
    required this.title,
    required this.description,
    this.isAutomatic = false,
  });
}

/// User error notification
class UserErrorNotification {
  final String id;
  final UserErrorType type;
  final String title;
  final String message;
  final UserNotificationSeverity severity;
  final List<UserRecoveryAction> recoveryActions;
  final DateTime timestamp;
  final bool canDismiss;
  final bool autoRetry;

  UserErrorNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.recoveryActions,
    required this.timestamp,
    this.canDismiss = true,
    this.autoRetry = false,
  });

  /// Check if notification is still relevant (not too old)
  bool get isRelevant {
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < 30; // Notifications are relevant for 30 minutes
  }
}
