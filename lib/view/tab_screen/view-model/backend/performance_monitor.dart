import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

/// Performance monitoring service for database and sync operations
/// Tracks memory usage, query performance, and sync operation metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<int>> _queryTimes = {};
  final Map<String, int> _queryCount = {};
  final Map<String, List<int>> _syncTimes = {};
  final Map<String, int> _memorySnapshots = {};
  final List<PerformanceMetric> _performanceHistory = [];
  
  Timer? _memoryMonitorTimer;
  bool _isMonitoring = false;

  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    developer.log('Performance monitoring started', name: 'PerformanceMonitor');
    
    // Monitor memory usage every 5 seconds
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _captureMemorySnapshot();
    });
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    developer.log('Performance monitoring stopped', name: 'PerformanceMonitor');
  }

  /// Track database query performance
  Future<T> trackQuery<T>(String queryName, Future<T> Function() queryFunction) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await queryFunction();
      stopwatch.stop();
      
      _recordQueryTime(queryName, stopwatch.elapsedMilliseconds);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordQueryTime('${queryName}_error', stopwatch.elapsedMilliseconds);
      rethrow;
    }
  }

  /// Track sync operation performance
  Future<T> trackSyncOperation<T>(String operationName, Future<T> Function() syncFunction) async {
    final stopwatch = Stopwatch()..start();
    final initialMemory = _getCurrentMemoryUsage();
    
    try {
      final result = await syncFunction();
      stopwatch.stop();
      
      final finalMemory = _getCurrentMemoryUsage();
      _recordSyncOperation(operationName, stopwatch.elapsedMilliseconds, initialMemory, finalMemory);
      
      return result;
    } catch (e) {
      stopwatch.stop();
      final finalMemory = _getCurrentMemoryUsage();
      _recordSyncOperation('${operationName}_error', stopwatch.elapsedMilliseconds, initialMemory, finalMemory);
      rethrow;
    }
  }

  /// Record query execution time
  void _recordQueryTime(String queryName, int milliseconds) {
    _queryTimes.putIfAbsent(queryName, () => []).add(milliseconds);
    _queryCount[queryName] = (_queryCount[queryName] ?? 0) + 1;
    
    // Keep only last 100 measurements per query
    if (_queryTimes[queryName]!.length > 100) {
      _queryTimes[queryName]!.removeAt(0);
    }
    
    // Log slow queries (> 1 second)
    if (milliseconds > 1000) {
      developer.log('Slow query detected: $queryName took ${milliseconds}ms', name: 'PerformanceMonitor');
    }
  }

  /// Record sync operation metrics
  void _recordSyncOperation(String operationName, int milliseconds, int initialMemory, int finalMemory) {
    _syncTimes.putIfAbsent(operationName, () => []).add(milliseconds);
    
    // Keep only last 50 sync measurements
    if (_syncTimes[operationName]!.length > 50) {
      _syncTimes[operationName]!.removeAt(0);
    }
    
    final memoryDelta = finalMemory - initialMemory;
    final metric = PerformanceMetric(
      operationName: operationName,
      duration: milliseconds,
      memoryUsage: finalMemory,
      memoryDelta: memoryDelta,
      timestamp: DateTime.now(),
    );
    
    _performanceHistory.add(metric);
    
    // Keep only last 200 performance metrics
    if (_performanceHistory.length > 200) {
      _performanceHistory.removeAt(0);
    }
    
    // Log memory-intensive operations (> 10MB increase)
    if (memoryDelta > 10 * 1024 * 1024) {
      developer.log('Memory-intensive operation: $operationName used ${(memoryDelta / 1024 / 1024).toStringAsFixed(2)}MB', 
                   name: 'PerformanceMonitor');
    }
  }

  /// Capture memory usage snapshot
  void _captureMemorySnapshot() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final memoryUsage = _getCurrentMemoryUsage();
    _memorySnapshots[timestamp.toString()] = memoryUsage;
    
    // Keep only last 100 snapshots (about 8 minutes of data)
    if (_memorySnapshots.length > 100) {
      final oldestKey = _memorySnapshots.keys.first;
      _memorySnapshots.remove(oldestKey);
    }
  }

  /// Get current memory usage in bytes
  int _getCurrentMemoryUsage() {
    try {
      // On mobile platforms, use ProcessInfo if available
      if (Platform.isAndroid || Platform.isIOS) {
        return ProcessInfo.currentRss;
      }
      
      // Fallback for other platforms
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get query performance statistics
  Map<String, dynamic> getQueryStatistics() {
    final stats = <String, dynamic>{};
    
    for (final queryName in _queryTimes.keys) {
      final times = _queryTimes[queryName]!;
      final count = _queryCount[queryName] ?? 0;
      
      if (times.isNotEmpty) {
        times.sort();
        final avg = times.reduce((a, b) => a + b) / times.length;
        final median = times[times.length ~/ 2];
        final p95 = times[(times.length * 0.95).floor()];
        final min = times.first;
        final max = times.last;
        
        stats[queryName] = {
          'count': count,
          'averageMs': avg.round(),
          'medianMs': median,
          'p95Ms': p95,
          'minMs': min,
          'maxMs': max,
        };
      }
    }
    
    return stats;
  }

  /// Get sync operation performance statistics
  Map<String, dynamic> getSyncStatistics() {
    final stats = <String, dynamic>{};
    
    for (final operationName in _syncTimes.keys) {
      final times = _syncTimes[operationName]!;
      
      if (times.isNotEmpty) {
        times.sort();
        final avg = times.reduce((a, b) => a + b) / times.length;
        final median = times[times.length ~/ 2];
        final p95 = times[(times.length * 0.95).floor()];
        final min = times.first;
        final max = times.last;
        
        stats[operationName] = {
          'count': times.length,
          'averageMs': avg.round(),
          'medianMs': median,
          'p95Ms': p95,
          'minMs': min,
          'maxMs': max,
        };
      }
    }
    
    return stats;
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStatistics() {
    if (_memorySnapshots.isEmpty) {
      return {
        'currentUsageMB': 0,
        'peakUsageMB': 0,
        'averageUsageMB': 0,
        'snapshotCount': 0,
      };
    }
    
    final values = _memorySnapshots.values.toList();
    values.sort();
    
    final current = values.last;
    final peak = values.last;
    final average = values.reduce((a, b) => a + b) / values.length;
    
    return {
      'currentUsageMB': (current / 1024 / 1024).toStringAsFixed(2),
      'peakUsageMB': (peak / 1024 / 1024).toStringAsFixed(2),
      'averageUsageMB': (average / 1024 / 1024).toStringAsFixed(2),
      'snapshotCount': values.length,
    };
  }

  /// Get comprehensive performance report
  Map<String, dynamic> getPerformanceReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'isMonitoring': _isMonitoring,
      'queryStatistics': getQueryStatistics(),
      'syncStatistics': getSyncStatistics(),
      'memoryStatistics': getMemoryStatistics(),
      'recentMetrics': _performanceHistory.take(10).map((m) => m.toMap()).toList(),
    };
  }

  /// Get performance recommendations based on collected metrics
  List<String> getPerformanceRecommendations() {
    final recommendations = <String>[];
    
    // Check for slow queries
    final queryStats = getQueryStatistics();
    for (final entry in queryStats.entries) {
      final stats = entry.value as Map<String, dynamic>;
      if (stats['p95Ms'] > 500) {
        recommendations.add('Query "${entry.key}" is slow (P95: ${stats['p95Ms']}ms). Consider optimization.');
      }
    }
    
    // Check memory usage
    final memoryStats = getMemoryStatistics();
    final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
    if (currentUsage > 100) {
      recommendations.add('High memory usage detected (${currentUsage.toStringAsFixed(1)}MB). Consider cleanup.');
    }
    
    // Check sync performance
    final syncStats = getSyncStatistics();
    for (final entry in syncStats.entries) {
      final stats = entry.value as Map<String, dynamic>;
      if (stats['p95Ms'] > 5000) {
        recommendations.add('Sync operation "${entry.key}" is slow (P95: ${stats['p95Ms']}ms). Check network conditions.');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Performance looks good! No issues detected.');
    }
    
    return recommendations;
  }

  /// Clear all performance data
  void clearMetrics() {
    _queryTimes.clear();
    _queryCount.clear();
    _syncTimes.clear();
    _memorySnapshots.clear();
    _performanceHistory.clear();
    developer.log('Performance metrics cleared', name: 'PerformanceMonitor');
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    clearMetrics();
  }
}

/// Performance metric data class
class PerformanceMetric {
  final String operationName;
  final int duration;
  final int memoryUsage;
  final int memoryDelta;
  final DateTime timestamp;

  PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.memoryUsage,
    required this.memoryDelta,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationName': operationName,
      'duration': duration,
      'memoryUsage': memoryUsage,
      'memoryDelta': memoryDelta,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}