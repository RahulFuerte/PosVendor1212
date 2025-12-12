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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
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
        _onConnectivityChanged,
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
      final List<ConnectivityResult> connectivityResults = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(connectivityResults);
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
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _updateConnectivityStatus(results);
  }

  /// Update connectivity status based on connectivity results
  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    final bool wasConnected = _isConnected;
    
    // Check if any of the connectivity results indicate a connection
    _isConnected = results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );

    // Only emit if connectivity status changed
    if (wasConnected != _isConnected) {
      _errorService.logInfo(
        'ConnectionMonitor',
        'Connectivity status changed',
        context: {
          'isConnected': _isConnected,
          'previousState': wasConnected,
          'connectionTypes': results.map((r) => r.name).toList(),
        },
      );
      _connectivityController.add(_isConnected);
    }
  }

  /// Manually check connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(results);
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