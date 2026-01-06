// Dart imports:
import 'dart:async';

// Project imports:
import 'connection_monitor.dart';

/// Network connectivity abstraction interface
abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get connectivityStream;
}

/// Network connectivity abstraction implementation using existing ConnectionMonitor
class NetworkInfoImpl implements NetworkInfo {
  final ConnectionMonitor _connectionMonitor;

  NetworkInfoImpl(this._connectionMonitor);

  /// Get current connection status
  @override
  Future<bool> get isConnected async {
    try {
      await _connectionMonitor.initialize();
      return _connectionMonitor.isConnected;
    } catch (e) {
      // If there's an error checking connectivity, assume disconnected
      return false;
    }
  }

  /// Get connectivity stream
  @override
  Stream<bool> get connectivityStream {
    return _connectionMonitor.connectivityStream;
  }
}
