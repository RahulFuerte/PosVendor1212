// Dart imports:
import 'dart:async';

// Project imports:
import 'error_handling_service.dart';
import 'user_error_service.dart';

/// Comprehensive error handler that integrates all error handling services
class ComprehensiveErrorHandler {
  static final ComprehensiveErrorHandler _instance = ComprehensiveErrorHandler._internal();
  factory ComprehensiveErrorHandler() => _instance;
  ComprehensiveErrorHandler._internal();

  final ErrorHandlingService _errorService = ErrorHandlingService();
  final UserErrorService _userErrorService = UserErrorService();

  bool _isInitialized = false;

  /// Initialize all error handling services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize services in order
      await _errorService.initialize();
      await _userErrorService.initialize();

      _isInitialized = true;

      await _errorService.logInfo(
        'ComprehensiveErrorHandler',
        'Comprehensive error handling system initialized successfully',
      );
    } catch (e) {
      print('Failed to initialize comprehensive error handler: $e');
      rethrow;
    }
  }

  /// Get the error handling service
  ErrorHandlingService get errorService => _errorService;

  /// Get the user error service
  UserErrorService get userErrorService => _userErrorService;

  /// Get the error recovery service

  /// Handle a critical error that requires immediate attention
  Future<void> handleCriticalError({
    required String component,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? userMessage,
  }) async {
    await _errorService.logError(
      component,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      severity: ErrorSeverity.critical,
      userMessage: userMessage ?? 'A critical error occurred. Please contact support.',
    );

    // Show immediate user notification for critical errors
    _userErrorService.showError(
      title: 'Critical Error',
      message: userMessage ?? 'A critical error occurred. Please contact support immediately.',
      severity: UserNotificationSeverity.error,
      canDismiss: false,
      recoveryActions: [
        UserRecoveryAction(
          id: 'contact_support',
          title: 'Contact Support',
          description: 'Get immediate help from technical support',
        ),
        UserRecoveryAction(
          id: 'export_logs',
          title: 'Export Logs',
          description: 'Export error logs to share with support',
        ),
      ],
    );
  }

  /// Handle a recoverable error with automatic retry
  Future<void> handleRecoverableError({
    required String component,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? userMessage,
    UserErrorType? errorType,
  }) async {
    await _errorService.logError(
      component,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      severity: ErrorSeverity.medium,
      userMessage: userMessage,
    );

    // The user error service will automatically handle this through its stream listener
    // and trigger recovery if the error type supports auto-retry
  }

  /// Handle a warning that doesn't require immediate action
  Future<void> handleWarning({
    required String component,
    required String message,
    Map<String, dynamic>? context,
    String? userMessage,
  }) async {
    await _errorService.logWarning(
      component,
      message,
      context: context,
      userMessage: userMessage,
    );
  }

  /// Handle an informational message
  Future<void> handleInfo({
    required String component,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    await _errorService.logInfo(
      component,
      message,
      context: context,
    );
  }

  /// Execute a recovery action and handle the result
  // Future<RecoveryResult> executeRecovery({
  //   required String actionId,
  //   required UserErrorType errorType,
  //   Map<String, dynamic>? parameters,
  // }) async {
  //   try {
  //     final result = await _recoveryService.executeRecoveryAction(
  //       actionId,
  //       errorType,
  //       parameters: parameters,
  //     );

  //     if (result.success) {
  //       _userErrorService.showSuccess(
  //         title: 'Recovery Successful',
  //         message: result.message,
  //       );
  //     } else {
  //       _userErrorService.showError(
  //         title: 'Recovery Failed',
  //         message: result.message,
  //         severity: UserNotificationSeverity.warning,
  //       );
  //     }

  //     return result;
  //   } catch (e) {
  //     await _errorService.logError(
  //       'ComprehensiveErrorHandler',
  //       'Recovery execution failed',
  //       error: e,
  //       context: {'actionId': actionId, 'errorType': errorType.name},
  //     );

  //     return RecoveryResult(
  //       success: false,
  //       message: 'Recovery execution failed: ${e.toString()}',
  //       actionId: actionId,
  //       timestamp: DateTime.now(),
  //     );
  //   }
  // }

  /// Get comprehensive error statistics
  // Future<Map<String, dynamic>> getErrorStatistics() async {
  //   final errorStats = _errorService.getErrorStatistics();

  //   return {
  //     'errorStatistics': errorStats,
  //     'recoveryStatistics': recoveryStats,
  //     'isHealthy': _isSystemHealthy(errorStats),
  //     'recommendations': _getHealthRecommendations(errorStats),
  //   };
  // }

  /// Check if the system is healthy based on error statistics
  bool _isSystemHealthy(Map<String, dynamic> errorStats) {
    final errorCount = errorStats['errorCount'] as int;
    final warningCount = errorStats['warningCount'] as int;

    // System is considered unhealthy if there are more than 10 errors or 20 warnings in the last hour
    return errorCount <= 10 && warningCount <= 20;
  }

  /// Get health recommendations based on error statistics
  List<String> _getHealthRecommendations(Map<String, dynamic> errorStats) {
    final recommendations = <String>[];
    final errorCount = errorStats['errorCount'] as int;
    final warningCount = errorStats['warningCount'] as int;
    final componentErrors = errorStats['componentErrors'] as Map<String, int>;

    if (errorCount > 10) {
      recommendations.add('High error count detected. Consider restarting the app or checking network connectivity.');
    }

    if (warningCount > 20) {
      recommendations.add('Many warnings detected. Review recent operations and consider clearing cache.');
    }

    if (componentErrors.isNotEmpty) {
      final mostProblematic = componentErrors.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (mostProblematic.value > 5) {
        recommendations.add('Component "${mostProblematic.key}" is experiencing frequent issues. Consider restarting or checking its configuration.');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('System is operating normally.');
    }

    return recommendations;
  }

  /// Export comprehensive error report
  Future<String?> exportErrorReport() async {
    try {
      final logPath = await _errorService.exportLogs();
      if (logPath != null) {
        await _errorService.logInfo(
          'ComprehensiveErrorHandler',
          'Error report exported successfully',
          context: {'exportPath': logPath},
        );
      }
      return logPath;
    } catch (e) {
      await _errorService.logError(
        'ComprehensiveErrorHandler',
        'Failed to export error report',
        error: e,
      );
      return null;
    }
  }

  /// Clear all error data
  Future<void> clearErrorData() async {
    try {
      await _errorService.clearLogs(clearFiles: true);
      // _recoveryService.cancelAllRecovery();

      await _errorService.logInfo(
        'ComprehensiveErrorHandler',
        'All error data cleared successfully',
      );
    } catch (e) {
      await _errorService.logError(
        'ComprehensiveErrorHandler',
        'Failed to clear error data',
        error: e,
      );
    }
  }

  /// Check if the error handling system is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose all resources
  void dispose() {
    _userErrorService.dispose();
    _errorService.dispose();
    _isInitialized = false;
  }
}

/// Convenience methods for common error scenarios
extension ErrorHandlerConvenience on ComprehensiveErrorHandler {
  /// Handle sync-related errors
  Future<void> handleSyncError(String message, {Object? error, String? userMessage}) async {
    await handleRecoverableError(
      component: 'SyncManager',
      message: message,
      error: error,
      userMessage: userMessage ?? 'Sync failed. We\'ll keep trying automatically.',
      errorType: UserErrorType.syncFailure,
    );
  }

  /// Handle network-related errors
  Future<void> handleNetworkError(String message, {Object? error, String? userMessage}) async {
    await handleRecoverableError(
      component: 'NetworkConnection',
      message: message,
      error: error,
      userMessage: userMessage ?? 'Network connection issue. Your data is saved locally.',
      errorType: UserErrorType.networkConnection,
    );
  }

  /// Handle database-related errors
  Future<void> handleDatabaseError(String message, {Object? error, String? userMessage, bool isCritical = false}) async {
    if (isCritical) {
      await handleCriticalError(
        component: 'Database',
        message: message,
        error: error,
        userMessage: userMessage ?? 'Critical database error. Please contact support.',
      );
    } else {
      await handleRecoverableError(
        component: 'Database',
        message: message,
        error: error,
        userMessage: userMessage ?? 'Database issue detected. Attempting recovery.',
        errorType: UserErrorType.databaseError,
      );
    }
  }

  /// Handle authentication errors
  Future<void> handleAuthError(String message, {Object? error, String? userMessage}) async {
    await handleRecoverableError(
      component: 'Authentication',
      message: message,
      error: error,
      userMessage: userMessage ?? 'Authentication required. Please sign in again.',
      errorType: UserErrorType.authenticationError,
    );
  }
}
