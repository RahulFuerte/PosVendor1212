import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'error_handling_service.dart';

/// Monitors network connectivity and provides connectivity status updates
class ConnectionMonitor {
  static final ConnectionMonitor _instance = ConnectionMonitor._internal();
  factory ConnectionMonitor() => _instance;
  ConnectionMonitor._internal();

  final Connectivity _connectivity = Connectivity();
  final ErrorHandlingService _errorService = ErrorHandlingService();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  bool _isInitialized = false;

  /// Stream that emits connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Initialize the connection monitor
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _errorService.initialize();

      // Check initial connectivity status
      await _checkInitialConnectivity();

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) => _onConnectivityChanged(result),
        onError: (error) {
          _errorService.logError(
            'ConnectionMonitor',
            'Connectivity monitoring error',
            error: error,
            severity: ErrorSeverity.medium,
            userMessage: 'There was a problem monitoring network connectivity.',
          );
        },
      );

      _isInitialized = true;
      await _errorService.logInfo('ConnectionMonitor', 'Connection monitor initialized successfully');
    } catch (e) {
      await _errorService.logError(
        'ConnectionMonitor',
        'Failed to initialize connection monitor',
        error: e,
        severity: ErrorSeverity.high,
      );
      rethrow;
    }
  }

  /// Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final ConnectivityResult connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(connectivityResult);
    } catch (e) {
      await _errorService.logError(
        'ConnectionMonitor',
        'Error checking initial connectivity',
        error: e,
        severity: ErrorSeverity.medium,
      );
      _isConnected = false;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    _updateConnectivityStatus(result);
  }

  /// Update connectivity status based on connectivity result
  void _updateConnectivityStatus(ConnectivityResult result) {
    final bool wasConnected = _isConnected;
    
    // Check if the connectivity result indicates a connection
    _isConnected = result == ConnectivityResult.mobile ||
                   result == ConnectivityResult.wifi ||
                   result == ConnectivityResult.ethernet ||
                   result == ConnectivityResult.vpn;

    // Only emit if connectivity status changed
    if (wasConnected != _isConnected) {
      _errorService.logInfo(
        'ConnectionMonitor',
        'Connectivity status changed',
        context: {
          'isConnected': _isConnected,
          'previousState': wasConnected,
          'connectionType': result.name,
        },
      );
      _connectivityController.add(_isConnected);
    }
  }

  /// Manually check connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);
      return _isConnected;
    } catch (e) {
      await _errorService.logError(
        'ConnectionMonitor',
        'Error during manual connectivity check',
        error: e,
        severity: ErrorSeverity.low,
      );
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _isInitialized = false;
  }
}