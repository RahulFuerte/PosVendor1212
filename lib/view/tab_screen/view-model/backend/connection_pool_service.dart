import 'dart:async';
import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import 'sqlite_helper.dart';

/// Connection pool service for optimized database access
class ConnectionPoolService {
  static final ConnectionPoolService _instance = ConnectionPoolService._internal();
  factory ConnectionPoolService() => _instance;
  ConnectionPoolService._internal();

  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final List<PooledConnection> _availableConnections = [];
  final List<PooledConnection> _activeConnections = [];
  
  bool _isInitialized = false;
  Timer? _maintenanceTimer;
  
  // Configuration
  static const int _minPoolSize = 2;
  static const int _maxPoolSize = 5;
  static const int _connectionTimeoutSeconds = 30;
  static const int _maintenanceIntervalSeconds = 60;

  /// Initialize the connection pool
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _sqliteHelper.initializeDatabase();
      
      // Create initial pool connections
      await _createInitialConnections();
      
      // Start maintenance timer
      _startMaintenanceTimer();
      
      _isInitialized = true;
      developer.log('ConnectionPoolService initialized with ${_availableConnections.length} connections', name: 'ConnectionPool');
    } catch (e) {
      developer.log('Error initializing ConnectionPoolService: $e', name: 'ConnectionPool');
      rethrow;
    }
  }

  /// Create initial pool connections
  Future<void> _createInitialConnections() async {
    for (int i = 0; i < _minPoolSize; i++) {
      final connection = await _createPooledConnection();
      _availableConnections.add(connection);
    }
  }

  /// Create a new pooled connection
  Future<PooledConnection> _createPooledConnection() async {
    final database = await _sqliteHelper.database;
    return PooledConnection(
      database: database,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );
  }

  /// Get a connection from the pool
  Future<PooledConnection> getConnection() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Try to get an available connection
    if (_availableConnections.isNotEmpty) {
      final connection = _availableConnections.removeAt(0);
      connection.lastUsed = DateTime.now();
      connection.isActive = true;
      _activeConnections.add(connection);
      
      developer.log('Reused pooled connection (${_activeConnections.length} active)', name: 'ConnectionPool');
      return connection;
    }

    // Create new connection if pool is not at max capacity
    if (_activeConnections.length < _maxPoolSize) {
      final connection = await _createPooledConnection();
      connection.isActive = true;
      _activeConnections.add(connection);
      
      developer.log('Created new pooled connection (${_activeConnections.length} active)', name: 'ConnectionPool');
      return connection;
    }

    // Wait for a connection to become available
    developer.log('Connection pool exhausted, waiting for available connection...', name: 'ConnectionPool');
    return await _waitForAvailableConnection();
  }

  /// Wait for a connection to become available
  Future<PooledConnection> _waitForAvailableConnection() async {
    final completer = Completer<PooledConnection>();
    
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_availableConnections.isNotEmpty) {
        timer.cancel();
        final connection = _availableConnections.removeAt(0);
        connection.lastUsed = DateTime.now();
        connection.isActive = true;
        _activeConnections.add(connection);
        completer.complete(connection);
      }
    });

    // Timeout after configured seconds
    Timer(Duration(seconds: _connectionTimeoutSeconds), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException(
          'Connection pool timeout after ${_connectionTimeoutSeconds}s',
          Duration(seconds: _connectionTimeoutSeconds),
        ));
      }
    });

    return completer.future;
  }

  /// Return a connection to the pool
  void returnConnection(PooledConnection connection) {
    if (!connection.isActive) {
      developer.log('Warning: Attempting to return inactive connection', name: 'ConnectionPool');
      return;
    }

    connection.isActive = false;
    connection.lastUsed = DateTime.now();
    
    _activeConnections.remove(connection);
    _availableConnections.add(connection);
    
    developer.log('Returned connection to pool (${_availableConnections.length} available)', name: 'ConnectionPool');
  }

  /// Execute query with automatic connection management
  Future<List<Map<String, dynamic>>> executeQuery(
    String sql,
    List<dynamic>? arguments, {
    String? queryName,
  }) async {
    final connection = await getConnection();
    
    try {
      final startTime = DateTime.now();
      final results = await connection.database.rawQuery(sql, arguments);
      final duration = DateTime.now().difference(startTime);
      
      if (queryName != null) {
        developer.log('Query $queryName executed in ${duration.inMilliseconds}ms', name: 'ConnectionPool');
      }
      
      return results;
    } finally {
      returnConnection(connection);
    }
  }

  /// Execute transaction with automatic connection management
  Future<T> executeTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final connection = await getConnection();
    
    try {
      return await connection.database.transaction(action);
    } finally {
      returnConnection(connection);
    }
  }

  /// Execute batch operations with automatic connection management
  Future<List<dynamic>> executeBatch(
    List<Map<String, dynamic>> operations,
  ) async {
    final connection = await getConnection();
    
    try {
      final batch = connection.database.batch();
      
      for (final operation in operations) {
        final sql = operation['sql'] as String;
        final arguments = operation['arguments'] as List<dynamic>?;
        
        if (operation['type'] == 'insert') {
          batch.rawInsert(sql, arguments);
        } else if (operation['type'] == 'update') {
          batch.rawUpdate(sql, arguments);
        } else if (operation['type'] == 'delete') {
          batch.rawDelete(sql, arguments);
        } else {
          batch.rawQuery(sql, arguments);
        }
      }
      
      return await batch.commit();
    } finally {
      returnConnection(connection);
    }
  }

  /// Start maintenance timer for connection pool health
  void _startMaintenanceTimer() {
    _maintenanceTimer = Timer.periodic(
      Duration(seconds: _maintenanceIntervalSeconds),
      (_) => _performMaintenance(),
    );
  }

  /// Perform connection pool maintenance
  void _performMaintenance() {
    final now = DateTime.now();
    
    // Remove stale connections
    _availableConnections.removeWhere((connection) {
      final age = now.difference(connection.lastUsed);
      if (age.inMinutes > 10) { // Remove connections unused for 10 minutes
        developer.log('Removing stale connection (unused for ${age.inMinutes} minutes)', name: 'ConnectionPool');
        return true;
      }
      return false;
    });
    
    // Ensure minimum pool size
    while (_availableConnections.length < _minPoolSize) {
      _createPooledConnection().then((connection) {
        _availableConnections.add(connection);
        developer.log('Added connection to maintain minimum pool size', name: 'ConnectionPool');
      }).catchError((e) {
        developer.log('Error creating maintenance connection: $e', name: 'ConnectionPool');
      });
    }
    
    // Log pool statistics
    final totalConnections = _availableConnections.length + _activeConnections.length;
    developer.log('Pool maintenance: ${_availableConnections.length} available, ${_activeConnections.length} active, $totalConnections total', name: 'ConnectionPool');
  }

  /// Get connection pool statistics
  Map<String, dynamic> getPoolStatistics() {
    final now = DateTime.now();
    final totalConnections = _availableConnections.length + _activeConnections.length;
    
    // Calculate average connection age
    final allConnections = [..._availableConnections, ..._activeConnections];
    final totalAge = allConnections.fold<int>(0, (sum, conn) => sum + now.difference(conn.createdAt).inSeconds);
    final averageAge = allConnections.isNotEmpty ? totalAge / allConnections.length : 0;
    
    return {
      'total_connections': totalConnections,
      'available_connections': _availableConnections.length,
      'active_connections': _activeConnections.length,
      'min_pool_size': _minPoolSize,
      'max_pool_size': _maxPoolSize,
      'average_connection_age_seconds': averageAge,
      'pool_utilization_percent': totalConnections > 0 ? (_activeConnections.length / totalConnections * 100).round() : 0,
    };
  }

  /// Check pool health
  bool isPoolHealthy() {
    final stats = getPoolStatistics();
    final utilizationPercent = stats['pool_utilization_percent'] as int;
    
    // Pool is healthy if utilization is below 80% and we have available connections
    return utilizationPercent < 80 && _availableConnections.isNotEmpty;
  }

  /// Force pool refresh (recreate all connections)
  Future<void> refreshPool() async {
    try {
      developer.log('Refreshing connection pool...', name: 'ConnectionPool');
      
      // Clear existing connections
      _availableConnections.clear();
      _activeConnections.clear();
      
      // Create fresh connections
      await _createInitialConnections();
      
      developer.log('Connection pool refreshed successfully', name: 'ConnectionPool');
    } catch (e) {
      developer.log('Error refreshing connection pool: $e', name: 'ConnectionPool');
      rethrow;
    }
  }

  /// Dispose the connection pool
  void dispose() {
    _maintenanceTimer?.cancel();
    _availableConnections.clear();
    _activeConnections.clear();
    _isInitialized = false;
    developer.log('ConnectionPoolService disposed', name: 'ConnectionPool');
  }
}

/// Pooled database connection wrapper
class PooledConnection {
  final Database database;
  final DateTime createdAt;
  DateTime lastUsed;
  bool isActive;

  PooledConnection({
    required this.database,
    required this.createdAt,
    required this.lastUsed,
    this.isActive = false,
  });

  /// Get connection age in seconds
  int get ageInSeconds => DateTime.now().difference(createdAt).inSeconds;

  /// Get time since last use in seconds
  int get timeSinceLastUseInSeconds => DateTime.now().difference(lastUsed).inSeconds;
}