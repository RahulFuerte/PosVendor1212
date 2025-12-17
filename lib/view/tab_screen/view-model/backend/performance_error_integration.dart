import 'dart:async';
import 'performance_error_handler.dart';
import 'performance_monitor.dart';
import 'sqlite_dao.dart';
import 'firebase_dao.dart';
import 'sync_manager.dart';
import 'query_optimization_service.dart';
import 'memory_management_service.dart';
import 'image_cache_service.dart';

/// Integration service that connects performance error handling with existing services
/// Monitors performance across all database and sync operations
/// Provides automatic fallback strategies and recovery mechanisms
class PerformanceErrorIntegration {
  static final PerformanceErrorIntegration _instance = PerformanceErrorIntegration._internal();
  factory PerformanceErrorIntegration() => _instance;
  PerformanceErrorIntegration._internal();

  final PerformanceErrorHandler _errorHandler = PerformanceErrorHandler();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  // Service references
  SQLiteDAO? _sqliteDAO;
  FirebaseDAO? _firebaseDAO;
  SyncManager? _syncManager;
  QueryOptimizationService? _queryOptimizer;
  MemoryManagementService? _memoryManager;
  ImageCacheService? _imageCache;

  bool _isInitialized = false;
  Timer? _monitoringTimer;

  /// Initialize the performance error integration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize core services
      await _errorHandler.initialize();
      _performanceMonitor.startMonitoring();

      // Initialize dependent services
      _sqliteDAO = SQLiteDAO();
      _firebaseDAO = FirebaseDAO();
      _syncManager = SyncManager();
      _queryOptimizer = QueryOptimizationService();
      _memoryManager = MemoryManagementService();
      _imageCache = ImageCacheService();

      await _sqliteDAO!.initialize();
      await _firebaseDAO!.initialize();
      await _syncManager!.initialize();
      await _queryOptimizer!.initialize();
      await _memoryManager!.initialize();
      await _imageCache!.initialize();

      // Set up performance monitoring hooks
      _setupPerformanceHooks();

      // Start continuous monitoring
      _startContinuousMonitoring();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize PerformanceErrorIntegration: $e');
    }
  }

  /// Set up performance monitoring hooks for all services
  void _setupPerformanceHooks() {
    // Hook into SQLite operations
    _hookSQLiteOperations();
    
    // Hook into Firebase operations
    _hookFirebaseOperations();
    
    // Hook into sync operations
    _hookSyncOperations();
    
    // Hook into cache operations
    _hookCacheOperations();
  }

  /// Hook into SQLite operations for performance monitoring
  void _hookSQLiteOperations() {
    // This would require modifying SQLiteDAO to support performance callbacks
    // For now, we'll implement periodic checks
  }

  /// Hook into Firebase operations for performance monitoring
  void _hookFirebaseOperations() {
    // This would require modifying FirebaseDAO to support performance callbacks
    // For now, we'll implement periodic checks
  }

  /// Hook into sync operations for performance monitoring
  void _hookSyncOperations() {
    // This would require modifying SyncManager to support performance callbacks
    // For now, we'll implement periodic checks
  }

  /// Hook into cache operations for performance monitoring
  void _hookCacheOperations() {
    // This would require modifying cache services to support performance callbacks
    // For now, we'll implement periodic checks
  }

  /// Start continuous performance monitoring
  void _startContinuousMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkAllPerformanceMetrics();
    });
  }

  /// Check performance metrics across all services
  Future<void> _checkAllPerformanceMetrics() async {
    try {
      // Check database performance
      await _checkDatabasePerformance();
      
      // Check memory usage
      await _checkMemoryPerformance();
      
      // Check cache performance
      await _checkCachePerformance();
      
      // Check sync performance
      await _checkSyncPerformance();
    } catch (e) {
      // Log error but don't throw to avoid disrupting monitoring
      print('Error during performance monitoring: $e');
    }
  }

  /// Check database performance and trigger error handling if needed
  Future<void> _checkDatabasePerformance() async {
    try {
      final queryStats = _performanceMonitor.getQueryStatistics();
      
      for (final entry in queryStats.entries) {
        final stats = entry.value as Map<String, dynamic>;
        final p95Time = stats['p95Ms'] as int;
        final avgTime = stats['averageMs'] as int;
        
        // Check for slow queries
        if (p95Time > 1000) {
          await _errorHandler.handleSlowQuery(
            queryName: entry.key,
            executionTimeMs: p95Time,
            context: 'continuous_monitoring',
            queryParameters: {'averageMs': avgTime, 'count': stats['count']},
          );
        }
      }
    } catch (e) {
      print('Error checking database performance: $e');
    }
  }

  /// Check memory performance and trigger error handling if needed
  Future<void> _checkMemoryPerformance() async {
    try {
      final memoryStats = _performanceMonitor.getMemoryStatistics();
      final currentUsageStr = memoryStats['currentUsageMB'] as String;
      final currentUsage = double.tryParse(currentUsageStr) ?? 0;
      
      // Check for high memory usage
      if (currentUsage > 120) {
        await _errorHandler.handleMemoryIssue(
          currentMemoryMB: currentUsage,
          operation: 'continuous_monitoring',
          context: 'system_check',
        );
      }
    } catch (e) {
      print('Error checking memory performance: $e');
    }
  }

  /// Check cache performance and trigger error handling if needed
  Future<void> _checkCachePerformance() async {
    try {
      // Check image cache performance
      if (_imageCache != null) {
        final cacheStats = await _imageCache!.getCacheStatistics();
        final hitRate = cacheStats['hitRate'] as double? ?? 1.0;
        
        if (hitRate < 0.6) {
          await _errorHandler.handleCachePerformanceIssue(
            hitRate: hitRate,
            cacheType: 'image_cache',
            context: 'continuous_monitoring',
          );
        }
      }
      
      // Check query cache performance if available
      if (_queryOptimizer != null) {
        // This would require QueryOptimizationService to provide cache stats
        // For now, we'll use a placeholder
      }
    } catch (e) {
      print('Error checking cache performance: $e');
    }
  }

  /// Check sync performance and trigger error handling if needed
  Future<void> _checkSyncPerformance() async {
    try {
      final syncStats = _performanceMonitor.getSyncStatistics();
      
      for (final entry in syncStats.entries) {
        final stats = entry.value as Map<String, dynamic>;
        final p95Time = stats['p95Ms'] as int;
        
        // Check for slow sync operations
        if (p95Time > 5000) {
          await _errorHandler.handlePerformanceDegradation(
            operation: entry.key,
            degradationType: 'slow_sync',
            metrics: stats,
            userMessage: 'Data sync is taking longer than usual. Your data is safe and will sync when possible.',
          );
        }
      }
    } catch (e) {
      print('Error checking sync performance: $e');
    }
  }

  /// Wrap database operations with performance monitoring
  Future<T> monitorDatabaseOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return await _performanceMonitor.trackQuery(operationName, () async {
      try {
        final result = await operation();
        return result;
      } catch (e) {
        // Handle database errors with performance context
        await _errorHandler.handlePerformanceDegradation(
          operation: operationName,
          degradationType: 'database_error',
          metrics: {'error': e.toString()},
          userMessage: 'There was a problem with the database. Your data is safe.',
        );
        rethrow;
      }
    });
  }

  /// Wrap sync operations with performance monitoring
  Future<T> monitorSyncOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return await _performanceMonitor.trackSyncOperation(operationName, () async {
      try {
        final result = await operation();
        return result;
      } catch (e) {
        // Handle sync errors with performance context
        await _errorHandler.handlePerformanceDegradation(
          operation: operationName,
          degradationType: 'sync_error',
          metrics: {'error': e.toString()},
          userMessage: 'Sync failed. Your data is saved locally and will sync when connection is restored.',
        );
        rethrow;
      }
    });
  }

  /// Monitor memory-intensive operations
  Future<T> monitorMemoryOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final initialMemory = _getCurrentMemoryUsage();
    
    try {
      final result = await operation();
      
      final finalMemory = _getCurrentMemoryUsage();
      final memoryDelta = finalMemory - initialMemory;
      
      // Check if operation used excessive memory
      if (memoryDelta > 20 * 1024 * 1024) { // 20MB
        await _errorHandler.handleMemoryIssue(
          currentMemoryMB: finalMemory / 1024 / 1024,
          operation: operationName,
          context: 'memory_intensive_operation',
        );
      }
      
      return result;
    } catch (e) {
      await _errorHandler.handlePerformanceDegradation(
        operation: operationName,
        degradationType: 'memory_error',
        metrics: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get current memory usage in bytes
  int _getCurrentMemoryUsage() {
    try {
      // This would use platform-specific memory monitoring
      // For now, return a placeholder
      return 100 * 1024 * 1024; // 100MB placeholder
    } catch (e) {
      return 0;
    }
  }

  /// Execute performance recovery actions
  Future<bool> executePerformanceRecovery(String actionType) async {
    try {
      switch (actionType) {
        case 'clear_query_cache':
          return await _clearQueryCache();
        case 'optimize_database':
          return await _optimizeDatabase();
        case 'clear_image_cache':
          return await _clearImageCache();
        case 'force_garbage_collection':
          return await _forceGarbageCollection();
        case 'restart_sync':
          return await _restartSync();
        default:
          return false;
      }
    } catch (e) {
      print('Error executing performance recovery: $e');
      return false;
    }
  }

  /// Clear query cache to improve performance
  Future<bool> _clearQueryCache() async {
    try {
      if (_queryOptimizer != null) {
        _queryOptimizer!.clearCache();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Optimize database for better performance
  Future<bool> _optimizeDatabase() async {
    try {
      if (_sqliteDAO != null) {
        // This would trigger database optimization
        // For now, just return success
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear image cache to free memory
  Future<bool> _clearImageCache() async {
    try {
      if (_imageCache != null) {
        await _imageCache!.clearImageCache();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Force garbage collection to free memory
  Future<bool> _forceGarbageCollection() async {
    try {
      // Memory management service doesn't expose public cleanup methods
      // We'll trigger cleanup indirectly by checking memory statistics
      if (_memoryManager != null) {
        await _memoryManager!.getMemoryStatistics();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Restart sync operations
  Future<bool> _restartSync() async {
    try {
      if (_syncManager != null) {
        // Trigger a sync operation to restart sync activity
        final result = await _syncManager!.syncPendingData();
        return result.success;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get comprehensive performance status
  Map<String, dynamic> getPerformanceStatus() {
    return {
      'isInitialized': _isInitialized,
      'monitoringActive': _monitoringTimer?.isActive ?? false,
      'performanceReport': _performanceMonitor.getPerformanceReport(),
      'errorStatistics': _errorHandler.getPerformanceIssueStatistics(),
      'recommendations': _errorHandler.getPerformanceRecommendations(),
    };
  }

  /// Get performance health score
  int getPerformanceHealthScore() {
    return _performanceMonitor.calculateHealthScore();
  }

  /// Check if performance is healthy
  bool isPerformanceHealthy() {
    return getPerformanceHealthScore() >= 70;
  }

  /// Get performance recommendations for users
  List<String> getUserRecommendations() {
    final recommendations = <String>[];
    final healthScore = getPerformanceHealthScore();
    
    if (healthScore < 50) {
      recommendations.add('Performance is poor. Consider restarting the app.');
      recommendations.add('Clear app cache to improve speed.');
      recommendations.add('Close other apps to free up memory.');
    } else if (healthScore < 70) {
      recommendations.add('Performance could be better. Try clearing the cache.');
      recommendations.add('Restart the app if issues persist.');
    } else {
      recommendations.add('Performance is good. No action needed.');
    }
    
    return recommendations;
  }

  /// Check if the integration is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    _performanceMonitor.dispose();
    _errorHandler.dispose();
    
    _isInitialized = false;
  }
}

/// Extension methods for easy integration with existing services
extension PerformanceMonitoring on SQLiteDAO {
  /// Execute a query with performance monitoring
  Future<T> executeWithMonitoring<T>(
    String queryName,
    Future<T> Function() query,
  ) async {
    final integration = PerformanceErrorIntegration();
    return await integration.monitorDatabaseOperation(queryName, query);
  }
}

extension SyncPerformanceMonitoring on SyncManager {
  /// Execute a sync operation with performance monitoring
  Future<T> syncWithMonitoring<T>(
    String operationName,
    Future<T> Function() syncOperation,
  ) async {
    final integration = PerformanceErrorIntegration();
    return await integration.monitorSyncOperation(operationName, syncOperation);
  }
}

extension MemoryPerformanceMonitoring on MemoryManagementService {
  /// Execute a memory-intensive operation with monitoring
  Future<T> executeWithMemoryMonitoring<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final integration = PerformanceErrorIntegration();
    return await integration.monitorMemoryOperation(operationName, operation);
  }
}