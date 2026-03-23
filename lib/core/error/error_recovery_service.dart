// Dart imports:
import 'dart:async';

// Project imports:
import '../../data/datasources/data_integrity_service.dart';
import '../../data/datasources/local/sqlite_dao.dart';
import '../../data/datasources/remote/firebase_dao.dart';
import '../../data/datasources/sync_manager.dart';
import '../network/connection_monitor.dart';
import 'error_handling_service.dart';
import 'user_error_service.dart';

/// Service for handling error recovery workflows and automatic recovery
class ErrorRecoveryService {
  static final ErrorRecoveryService _instance = ErrorRecoveryService._internal();
  factory ErrorRecoveryService() => _instance;
  ErrorRecoveryService._internal();

  final ErrorHandlingService _errorService = ErrorHandlingService();
  final UserErrorService _userErrorService = UserErrorService();
  final StreamController<RecoveryProgress> _progressController = 
      StreamController<RecoveryProgress>.broadcast();

  SyncManager? _syncManager;
  ConnectionMonitor? _connectionMonitor;
  DataIntegrityService? _dataIntegrityService;
  SQLiteDAO? _sqliteDAO;
  NodeApiDAO? _NodeApiDAO;

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

      // Initialize dependencies
      _syncManager = SyncManager();
      _connectionMonitor = ConnectionMonitor();
      _dataIntegrityService = DataIntegrityService();
      _sqliteDAO = SQLiteDAO();
      _NodeApiDAO = NodeApiDAO();

      await _syncManager!.initialize();
      await _connectionMonitor!.initialize();
      await _dataIntegrityService!.initialize();
      await _sqliteDAO!.initialize();
      await _NodeApiDAO!.initialize();

      // Listen for user error notifications and handle automatic recovery
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

  /// Handle user error notifications and trigger automatic recovery if applicable
  void _handleUserNotification(UserErrorNotification notification) {
    if (notification.autoRetry) {
      _scheduleAutoRecovery(notification);
    }
  }

  /// Schedule automatic recovery for retriable errors
  void _scheduleAutoRecovery(UserErrorNotification notification) {
    final retryKey = '${notification.type.name}_${notification.id}';
    
    // Cancel existing timer if any
    _retryTimers[retryKey]?.cancel();
    
    // Get current retry attempt count
    final currentAttempts = _retryAttempts[retryKey] ?? 0;
    
    // Maximum retry attempts
    const maxAttempts = 3;
    
    if (currentAttempts >= maxAttempts) {
      _errorService.logWarning(
        'ErrorRecoveryService',
        'Maximum retry attempts reached for ${notification.type.name}',
        context: {'notificationId': notification.id, 'attempts': currentAttempts},
      );
      return;
    }

    // Calculate retry delay with exponential backoff
    final delaySeconds = _calculateRetryDelay(currentAttempts);
    
    _errorService.logInfo(
      'ErrorRecoveryService',
      'Scheduling auto recovery for ${notification.type.name}',
      context: {
        'attempt': currentAttempts + 1,
        'delaySeconds': delaySeconds,
        'notificationId': notification.id,
      },
    );

    _retryTimers[retryKey] = Timer(Duration(seconds: delaySeconds), () async {
      _retryAttempts[retryKey] = currentAttempts + 1;
      await _executeAutoRecovery(notification);
    });
  }

  /// Calculate retry delay with exponential backoff and jitter
  int _calculateRetryDelay(int attemptNumber) {
    // Base delay: 30 seconds, 60 seconds, 120 seconds
    final baseDelay = 30 * (1 << attemptNumber);
    
    // Add jitter (±25%)
    final jitter = (baseDelay * 0.25 * (DateTime.now().millisecond / 1000)).round();
    
    return baseDelay + jitter;
  }

  /// Execute automatic recovery for a notification
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
          
        case UserErrorType.syncFailure:
          success = await _recoverSyncFailure();
          break;
          
        case UserErrorType.cloudServiceError:
          success = await _recoverCloudServiceError();
          break;
          
        case UserErrorType.databaseCorruption:
          success = await _recoverDatabaseCorruption();
          break;
          
        default:
          // No automatic recovery available for this error type
          success = false;
      }

      if (success) {
        _progressController.add(RecoveryProgress(
          id: recoveryId,
          type: notification.type,
          status: RecoveryStatus.completed,
          message: 'Automatic recovery completed successfully',
          progress: 1.0,
        ));

        _userErrorService.showSuccess(
          title: 'Problem Resolved',
          message: 'The issue has been automatically resolved.',
        );

        // Clear retry attempts on success
        final retryKey = '${notification.type.name}_${notification.id}';
        _retryAttempts.remove(retryKey);
        _retryTimers.remove(retryKey);
        
      } else {
        _progressController.add(RecoveryProgress(
          id: recoveryId,
          type: notification.type,
          status: RecoveryStatus.failed,
          message: 'Automatic recovery failed',
          progress: 0.0,
        ));
      }
      
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Auto recovery failed for ${notification.type.name}',
        error: e,
        context: {'notificationId': notification.id},
      );

      _progressController.add(RecoveryProgress(
        id: recoveryId,
        type: notification.type,
        status: RecoveryStatus.failed,
        message: 'Automatic recovery encountered an error: ${e.toString()}',
        progress: 0.0,
      ));
    }
  }

  /// Recover from network connection issues
  Future<bool> _recoverNetworkConnection() async {
    try {
      // Check if connection is restored
      final isConnected = await _connectionMonitor!.checkConnectivity();
      
      if (isConnected) {
        // Trigger sync if connection is restored
        final syncResult = await _syncManager!.syncPendingData();
        return syncResult.success;
      }
      
      return false;
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Network connection recovery failed',
        error: e,
      );
      return false;
    }
  }

  /// Recover from sync failures
  Future<bool> _recoverSyncFailure() async {
    try {
      // Check connection first
      final isConnected = await _connectionMonitor!.checkConnectivity();
      if (!isConnected) {
        return false;
      }

      // Attempt sync again
      final syncResult = await _syncManager!.syncPendingData();
      return syncResult.success;
      
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Sync failure recovery failed',
        error: e,
      );
      return false;
    }
  }

  /// Recover from cloud service errors
  Future<bool> _recoverCloudServiceError() async {
    try {
      // Re-initialize Firebase connection
      await _NodeApiDAO!.initialize();
      
      // Test connection with a simple operation
      // This would depend on having a test method in NodeApiDAO
      
      // If successful, trigger sync
      final syncResult = await _syncManager!.syncPendingData();
      return syncResult.success;
      
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Cloud service recovery failed',
        error: e,
      );
      return false;
    }
  }

  /// Recover from database corruption
  Future<bool> _recoverDatabaseCorruption() async {
    try {
      // This is a critical operation, so we need admin UID
      // For now, we'll attempt recovery without it and let the service handle it
      final recoveryResult = await _dataIntegrityService!.detectAndRecoverCorruption('');
      
      return recoveryResult.recoverySuccessful;
      
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Database corruption recovery failed',
        error: e,
        severity: ErrorSeverity.critical,
      );
      return false;
    }
  }

  /// Execute manual recovery action
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
        case 'retry_sync':
          success = await _recoverSyncFailure();
          message = success ? 'Sync completed successfully' : 'Sync failed again';
          break;
          
        case 'check_connection':
          success = await _connectionMonitor!.checkConnectivity();
          message = success ? 'Connection is available' : 'No connection available';
          break;
          
        case 'retry_operation':
          // Generic retry - would need more context
          success = true;
          message = 'Please try your operation again';
          break;
          
        case 'auto_recovery':
          if (errorType == UserErrorType.databaseCorruption) {
            success = await _recoverDatabaseCorruption();
            message = success ? 'Database recovered successfully' : 'Database recovery failed';
          }
          break;
          
        case 'manual_recovery':
          // This would open a UI for manual backup selection
          success = true;
          message = 'Manual recovery options available';
          break;
          
        case 'clear_cache':
          success = await _clearAppCache();
          message = success ? 'Cache cleared successfully' : 'Failed to clear cache';
          break;
          
        case 'clear_image_cache':
          success = await _clearImageCache();
          message = success ? 'Image cache cleared successfully' : 'Failed to clear image cache';
          break;
          
        case 'retry_backup':
          success = await _retryBackup();
          message = success ? 'Backup created successfully' : 'Backup failed again';
          break;
          
        default:
          success = false;
          message = 'Unknown recovery action';
      }

      final status = success ? RecoveryStatus.completed : RecoveryStatus.failed;
      
      _progressController.add(RecoveryProgress(
        id: recoveryId,
        type: errorType,
        status: status,
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
      await _errorService.logError(
        'ErrorRecoveryService',
        'Manual recovery action failed',
        error: e,
        context: {'actionId': actionId, 'errorType': errorType.name},
      );

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

  /// Clear application cache
  Future<bool> _clearAppCache() async {
    try {
      // This would clear various caches
      // For now, just clear image cache as an example
      await _sqliteDAO!.clearImageCache();
      return true;
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Failed to clear app cache',
        error: e,
      );
      return false;
    }
  }

  /// Clear image cache
  Future<bool> _clearImageCache() async {
    try {
      await _sqliteDAO!.clearImageCache();
      return true;
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Failed to clear image cache',
        error: e,
      );
      return false;
    }
  }

  /// Retry backup operation
  Future<bool> _retryBackup() async {
    try {
      final backupResult = await _dataIntegrityService!.createDatabaseBackup();
      return backupResult.success;
    } catch (e) {
      await _errorService.logError(
        'ErrorRecoveryService',
        'Failed to retry backup',
        error: e,
      );
      return false;
    }
  }

  /// Get recovery workflow for a specific error type
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
              id: 'toggle_connection',
              title: 'Toggle Connection',
              description: 'Turn Wi-Fi or mobile data off and on again',
              isAutomatic: false,
            ),
            RecoveryStep(
              id: 'retry_sync',
              title: 'Retry Sync',
              description: 'Try syncing your data again',
              isAutomatic: true,
            ),
          ],
        );

      case UserErrorType.syncFailure:
        return RecoveryWorkflow(
          errorType: errorType,
          steps: [
            RecoveryStep(
              id: 'check_connection',
              title: 'Verify Connection',
              description: 'Make sure you have a stable internet connection',
              isAutomatic: true,
            ),
            RecoveryStep(
              id: 'wait_and_retry',
              title: 'Wait and Retry',
              description: 'Wait a moment and try syncing again',
              isAutomatic: true,
            ),
            RecoveryStep(
              id: 'check_account',
              title: 'Check Account',
              description: 'Verify your account is still valid and has permissions',
              isAutomatic: false,
            ),
          ],
        );

      case UserErrorType.databaseCorruption:
        return RecoveryWorkflow(
          errorType: errorType,
          steps: [
            RecoveryStep(
              id: 'auto_recovery',
              title: 'Automatic Recovery',
              description: 'Attempt to recover data from cloud backup',
              isAutomatic: true,
            ),
            RecoveryStep(
              id: 'manual_backup_selection',
              title: 'Choose Backup',
              description: 'Select a specific backup to restore from',
              isAutomatic: false,
            ),
            RecoveryStep(
              id: 'contact_support',
              title: 'Contact Support',
              description: 'Get help from technical support if recovery fails',
              isAutomatic: false,
            ),
          ],
        );

      case UserErrorType.storageError:
        return RecoveryWorkflow(
          errorType: errorType,
          steps: [
            RecoveryStep(
              id: 'check_storage',
              title: 'Check Available Storage',
              description: 'View how much storage space is available on your device',
              isAutomatic: false,
            ),
            RecoveryStep(
              id: 'clear_cache',
              title: 'Clear App Cache',
              description: 'Free up space by clearing temporary files',
              isAutomatic: true,
            ),
            RecoveryStep(
              id: 'delete_old_backups',
              title: 'Clean Old Backups',
              description: 'Remove old backup files to free up space',
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
            RecoveryStep(
              id: 'restart_app',
              title: 'Restart App',
              description: 'Close and reopen the app to reset its state',
              isAutomatic: false,
            ),
          ],
        );
    }
  }

  /// Cancel all pending recovery operations
  void cancelAllRecovery() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
    
    _errorService.logInfo('ErrorRecoveryService', 'All recovery operations cancelled');
  }

  /// Get recovery statistics
  Map<String, dynamic> getRecoveryStatistics() {
    return {
      'activeRetryOperations': _retryTimers.length,
      'totalRetryAttempts': _retryAttempts.values.fold(0, (sum, attempts) => sum + attempts),
      'retryOperationsByType': _retryAttempts.keys.map((key) => key.split('_')[0]).toSet().toList(),
    };
  }

  /// Dispose resources
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
  final double progress; // 0.0 to 1.0

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
