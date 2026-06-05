// Dart imports:
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Comprehensive error handling and logging service for sync operations
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  final List<LogEntry> _logBuffer = [];
  static const int _maxLogBufferSize = 1000;

  bool _isInitialized = false;
  String? _logFilePath;

  /// Stream that emits log entries
  Stream<LogEntry> get logStream => _logController.stream;

  /// Initialize the error handling service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeLogFile();
      _isInitialized = true;

      // Log initialization
      await logInfo('ErrorHandlingService', 'Error handling service initialized successfully');
    } catch (e) {
      print('Failed to initialize ErrorHandlingService: $e');
    }
  }

  /// Initialize log file for persistent logging
  Future<void> _initializeLogFile() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDocDir.path}${Platform.pathSeparator}logs');

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      _logFilePath = '${logDir.path}${Platform.pathSeparator}sync_log_$timestamp.txt';

      // Create log file if it doesn't exist
      final logFile = File(_logFilePath!);
      if (!await logFile.exists()) {
        await logFile.create();
        await logFile.writeAsString('=== Sync Log Started at ${DateTime.now().toIso8601String()} ===\n');
      }
    } catch (e) {
      print('Failed to initialize log file: $e');
    }
  }

  /// Log an error with context and recovery suggestions
  Future<void> logError(
    String component,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    ErrorSeverity severity = ErrorSeverity.high,
    String? userMessage,
    List<RecoveryAction>? recoveryActions,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.error,
      component: component,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      severity: severity,
      userMessage: userMessage,
      recoveryActions: recoveryActions,
      timestamp: DateTime.now(),
    );

    await _processLogEntry(logEntry);
  }

  /// Log a warning with context
  Future<void> logWarning(
    String component,
    String message, {
    Map<String, dynamic>? context,
    String? userMessage,
    List<RecoveryAction>? recoveryActions,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.warning,
      component: component,
      message: message,
      context: context,
      userMessage: userMessage,
      recoveryActions: recoveryActions,
      timestamp: DateTime.now(),
    );

    await _processLogEntry(logEntry);
  }

  /// Log an info message
  Future<void> logInfo(
    String component,
    String message, {
    Map<String, dynamic>? context,
  }) async {
    final logEntry = LogEntry(
      level: LogLevel.info,
      component: component,
      message: message,
      context: context,
      timestamp: DateTime.now(),
    );

    await _processLogEntry(logEntry);
  }

  /// Log a debug message (only in debug mode)
  Future<void> logDebug(
    String component,
    String message, {
    Map<String, dynamic>? context,
  }) async {
    // Only log debug messages in debug mode
    bool isDebugMode = false;
    assert(isDebugMode = true);

    if (!isDebugMode) return;

    final logEntry = LogEntry(
      level: LogLevel.debug,
      component: component,
      message: message,
      context: context,
      timestamp: DateTime.now(),
    );

    await _processLogEntry(logEntry);
  }

  /// Process and store log entry
  Future<void> _processLogEntry(LogEntry entry) async {
    // Add to buffer
    _logBuffer.add(entry);

    // Maintain buffer size
    if (_logBuffer.length > _maxLogBufferSize) {
      _logBuffer.removeAt(0);
    }

    // Emit to stream
    _logController.add(entry);

    // Write to console for immediate visibility
    _writeToConsole(entry);

    // Write to file for persistence
    await _writeToFile(entry);
  }

  /// Write log entry to console with formatting
  void _writeToConsole(LogEntry entry) {
    if (entry.stackTrace != null) {}
  }

  /// Write log entry to file
  Future<void> _writeToFile(LogEntry entry) async {
    if (_logFilePath == null) return;

    try {
      final logFile = File(_logFilePath!);
      final timestamp = entry.timestamp.toIso8601String();
      final level = entry.level.name.toUpperCase();

      String logLine = '[$timestamp] [$level] [${entry.component}] ${entry.message}';

      if (entry.context != null && entry.context!.isNotEmpty) {
        logLine += ' | Context: ${entry.context}';
      }

      if (entry.error != null) {
        logLine += ' | Error: ${entry.error}';
      }

      if (entry.stackTrace != null) {
        logLine += ' | Stack: ${entry.stackTrace.toString().replaceAll('\n', ' | ')}';
      }

      logLine += '\n';

      await logFile.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  /// Get recent log entries
  List<LogEntry> getRecentLogs({int? limit, LogLevel? minLevel}) {
    var logs = List<LogEntry>.from(_logBuffer);

    if (minLevel != null) {
      logs = logs.where((log) => log.level.index >= minLevel.index).toList();
    }

    if (limit != null && logs.length > limit) {
      logs = logs.sublist(logs.length - limit);
    }

    return logs.reversed.toList(); // Most recent first
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics({Duration? timeWindow}) {
    final cutoffTime = timeWindow != null ? DateTime.now().subtract(timeWindow) : DateTime.now().subtract(const Duration(hours: 24));

    final recentLogs = _logBuffer.where((log) => log.timestamp.isAfter(cutoffTime)).toList();

    final errorCount = recentLogs.where((log) => log.level == LogLevel.error).length;
    final warningCount = recentLogs.where((log) => log.level == LogLevel.warning).length;
    final infoCount = recentLogs.where((log) => log.level == LogLevel.info).length;

    final componentErrors = <String, int>{};
    for (final log in recentLogs.where((log) => log.level == LogLevel.error)) {
      componentErrors[log.component] = (componentErrors[log.component] ?? 0) + 1;
    }

    return {
      'timeWindow': timeWindow?.inHours ?? 24,
      'totalLogs': recentLogs.length,
      'errorCount': errorCount,
      'warningCount': warningCount,
      'infoCount': infoCount,
      'componentErrors': componentErrors,
      'mostProblematicComponent': componentErrors.isNotEmpty ? componentErrors.entries.reduce((a, b) => a.value > b.value ? a : b).key : null,
    };
  }

  /// Clear log buffer and optionally log files
  Future<void> clearLogs({bool clearFiles = false}) async {
    _logBuffer.clear();

    if (clearFiles && _logFilePath != null) {
      try {
        final logFile = File(_logFilePath!);
        if (await logFile.exists()) {
          await logFile.delete();
        }
        await _initializeLogFile();
      } catch (e) {
        await logError('ErrorHandlingService', 'Failed to clear log files', error: e);
      }
    }

    await logInfo('ErrorHandlingService', 'Log buffer cleared');
  }

  /// Export logs to a file
  Future<String?> exportLogs({DateTime? startDate, DateTime? endDate}) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDocDir.path}${Platform.pathSeparator}exports');

      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final exportPath = '${exportDir.path}${Platform.pathSeparator}sync_logs_export_$timestamp.txt';

      var logsToExport = List<LogEntry>.from(_logBuffer);

      if (startDate != null) {
        logsToExport = logsToExport.where((log) => log.timestamp.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        logsToExport = logsToExport.where((log) => log.timestamp.isBefore(endDate)).toList();
      }

      final exportFile = File(exportPath);
      final buffer = StringBuffer();

      buffer.writeln('=== Sync Logs Export ===');
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Total entries: ${logsToExport.length}');
      buffer.writeln('');

      for (final log in logsToExport) {
        buffer.writeln('${log.timestamp.toIso8601String()} | ${log.level.name.toUpperCase()} | ${log.component}');
        buffer.writeln('Message: ${log.message}');

        if (log.context != null && log.context!.isNotEmpty) {
          buffer.writeln('Context: ${log.context}');
        }

        if (log.error != null) {
          buffer.writeln('Error: ${log.error}');
        }

        if (log.userMessage != null) {
          buffer.writeln('User Message: ${log.userMessage}');
        }

        if (log.recoveryActions != null && log.recoveryActions!.isNotEmpty) {
          buffer.writeln('Recovery Actions:');
          for (final action in log.recoveryActions!) {
            buffer.writeln('  - ${action.description}');
          }
        }

        buffer.writeln('---');
      }

      await exportFile.writeAsString(buffer.toString());

      await logInfo('ErrorHandlingService', 'Logs exported successfully', context: {'exportPath': exportPath, 'entryCount': logsToExport.length});

      return exportPath;
    } catch (e) {
      await logError('ErrorHandlingService', 'Failed to export logs', error: e);
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _logController.close();
    _logBuffer.clear();
    _isInitialized = false;
  }
}

/// Log entry levels
enum LogLevel {
  debug,
  info,
  warning,
  error;
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical;
}

/// Recovery action that can be taken for an error
class RecoveryAction {
  final String id;
  final String description;
  final Future<bool> Function() action;
  final bool isAutomatic;

  RecoveryAction({
    required this.id,
    required this.description,
    required this.action,
    this.isAutomatic = false,
  });
}

/// Log entry containing all relevant information
class LogEntry {
  final LogLevel level;
  final String component;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;
  final ErrorSeverity? severity;
  final String? userMessage;
  final List<RecoveryAction>? recoveryActions;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.component,
    required this.message,
    this.error,
    this.stackTrace,
    this.context,
    this.severity,
    this.userMessage,
    this.recoveryActions,
    required this.timestamp,
  });

  /// Convert to user-friendly message
  String get userFriendlyMessage {
    if (userMessage != null) {
      return userMessage!;
    }

    // Generate user-friendly message based on component and error type
    switch (component) {
      case 'SyncManager':
        if (message.contains('No internet connection')) {
          return 'Unable to sync data. Please check your internet connection and try again.';
        } else if (message.contains('Firebase')) {
          return 'There was a problem connecting to the cloud. Your data is saved locally and will sync when the connection is restored.';
        } else if (message.contains('conflict')) {
          return 'Some data conflicts were detected and resolved automatically.';
        }
        return 'There was a problem syncing your data. Please try again.';

      case 'SQLiteDAO':
        if (message.contains('database')) {
          return 'There was a problem with the local database. Your data may need to be restored.';
        }
        return 'There was a problem saving your data locally.';

      case 'ConnectionMonitor':
        return 'Network connection status has changed.';

      case 'DataIntegrityService':
        if (message.contains('corruption')) {
          return 'Data corruption was detected. Attempting automatic recovery.';
        } else if (message.contains('backup')) {
          return 'There was a problem creating a backup of your data.';
        }
        return 'There was a problem with data integrity checks.';

      default:
        return message;
    }
  }
}
