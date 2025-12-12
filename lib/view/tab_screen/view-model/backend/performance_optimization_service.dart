import 'dart:async';
import 'dart:developer' as developer;
import 'performance_monitor.dart';
import 'lazy_loading_service.dart';
import 'image_cache_service.dart';
import 'sqlite_dao.dart';
import 'sync_manager.dart';
import 'database_service.dart';

/// Comprehensive performance optimization service
/// Coordinates all performance-related services and provides optimization recommendations
class PerformanceOptimizationService {
  static final PerformanceOptimizationService _instance = PerformanceOptimizationService._internal();
  factory PerformanceOptimizationService() => _instance;
  PerformanceOptimizationService._internal();

  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();
  final ImageCacheService _imageCacheService = ImageCacheService();
  
  Timer? _optimizationTimer;
  bool _isOptimizing = false;
  
  /// Initialize performance optimization service
  Future<void> initialize() async {
    developer.log('Initializing Performance Optimization Service', name: 'PerformanceOptimization');
    
    // Start performance monitoring
    _performanceMonitor.startMonitoring();
    
    // Schedule periodic optimization
    _schedulePeriodicOptimization();
    
    developer.log('Performance Optimization Service initialized', name: 'PerformanceOptimization');
  }

  /// Schedule periodic optimization tasks
  void _schedulePeriodicOptimization() {
    _optimizationTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _performPeriodicOptimization();
    });
  }

  /// Perform periodic optimization tasks
  Future<void> _performPeriodicOptimization() async {
    if (_isOptimizing) return;
    
    _isOptimizing = true;
    
    try {
      developer.log('Starting periodic optimization', name: 'PerformanceOptimization');
      
      // Clean up expired lazy loading caches
      _lazyLoadingService.cleanupExpiredCaches();
      
      // Perform image cache maintenance
      await _imageCacheService.performMaintenance();
      
      // Generate and log performance recommendations
      final recommendations = _performanceMonitor.getPerformanceRecommendations();
      if (recommendations.isNotEmpty) {
        developer.log('Performance recommendations: ${recommendations.join(', ')}', 
                     name: 'PerformanceOptimization');
      }
      
      developer.log('Periodic optimization completed', name: 'PerformanceOptimization');
    } catch (e) {
      developer.log('Error during periodic optimization: $e', name: 'PerformanceOptimization');
    } finally {
      _isOptimizing = false;
    }
  }

  /// Optimize database queries for better performance
  Future<void> optimizeDatabaseQueries(DatabaseService databaseService) async {
    developer.log('Optimizing database queries', name: 'PerformanceOptimization');
    
    try {
      if (databaseService is SQLiteDAO) {
        // Analyze query performance and suggest optimizations
        final queryStats = _performanceMonitor.getQueryStatistics();
        
        for (final entry in queryStats.entries) {
          final queryName = entry.key;
          final stats = entry.value as Map<String, dynamic>;
          
          if (stats['p95Ms'] > 1000) {
            developer.log('Slow query detected: $queryName (P95: ${stats['p95Ms']}ms)', 
                         name: 'PerformanceOptimization');
            
            // Suggest specific optimizations based on query type
            _suggestQueryOptimizations(queryName, stats);
          }
        }
      }
    } catch (e) {
      developer.log('Error optimizing database queries: $e', name: 'PerformanceOptimization');
    }
  }

  /// Suggest query optimizations based on performance data
  void _suggestQueryOptimizations(String queryName, Map<String, dynamic> stats) {
    final suggestions = <String>[];
    
    if (queryName.contains('getFoodItems') && stats['p95Ms'] > 500) {
      suggestions.add('Consider using pagination for getFoodItems queries');
      suggestions.add('Add indexes on frequently filtered columns (department, name)');
    }
    
    if (queryName.contains('getBills') && stats['p95Ms'] > 1000) {
      suggestions.add('Use date range indexes for bill queries');
      suggestions.add('Consider archiving old bills to reduce query time');
    }
    
    if (queryName.contains('search') && stats['p95Ms'] > 800) {
      suggestions.add('Implement full-text search indexes for better search performance');
      suggestions.add('Limit search results and use pagination');
    }
    
    for (final suggestion in suggestions) {
      developer.log('Optimization suggestion for $queryName: $suggestion', 
                   name: 'PerformanceOptimization');
    }
  }

  /// Optimize memory usage across all services
  Future<void> optimizeMemoryUsage() async {
    developer.log('Optimizing memory usage', name: 'PerformanceOptimization');
    
    try {
      // Get current memory statistics
      final memoryStats = _performanceMonitor.getMemoryStatistics();
      final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
      
      if (currentUsage > 100) {
        developer.log('High memory usage detected: ${currentUsage.toStringAsFixed(1)}MB', 
                     name: 'PerformanceOptimization');
        
        // Clear lazy loading caches
        _lazyLoadingService.clearAllCaches();
        
        // Perform aggressive image cache cleanup
        await _imageCacheService.manageCacheSize();
        
        // Force garbage collection (if available)
        developer.log('Performed memory cleanup due to high usage', name: 'PerformanceOptimization');
      }
    } catch (e) {
      developer.log('Error optimizing memory usage: $e', name: 'PerformanceOptimization');
    }
  }

  /// Optimize sync operations for better performance
  Future<void> optimizeSyncOperations(SyncManager syncManager) async {
    developer.log('Optimizing sync operations', name: 'PerformanceOptimization');
    
    try {
      final syncStats = _performanceMonitor.getSyncStatistics();
      
      for (final entry in syncStats.entries) {
        final operationName = entry.key;
        final stats = entry.value as Map<String, dynamic>;
        
        if (stats['p95Ms'] > 10000) { // 10 seconds
          developer.log('Slow sync operation detected: $operationName (P95: ${stats['p95Ms']}ms)', 
                       name: 'PerformanceOptimization');
          
          _suggestSyncOptimizations(operationName, stats);
        }
      }
    } catch (e) {
      developer.log('Error optimizing sync operations: $e', name: 'PerformanceOptimization');
    }
  }

  /// Suggest sync optimizations based on performance data
  void _suggestSyncOptimizations(String operationName, Map<String, dynamic> stats) {
    final suggestions = <String>[];
    
    if (operationName.contains('syncPendingData')) {
      suggestions.add('Consider reducing batch size for sync operations');
      suggestions.add('Implement incremental sync to reduce data transfer');
    }
    
    if (operationName.contains('syncFromFirebase')) {
      suggestions.add('Use timestamp-based incremental sync');
      suggestions.add('Implement compression for large data transfers');
    }
    
    for (final suggestion in suggestions) {
      developer.log('Sync optimization suggestion for $operationName: $suggestion', 
                   name: 'PerformanceOptimization');
    }
  }

  /// Get comprehensive performance analysis
  Future<Map<String, dynamic>> getPerformanceAnalysis() async {
    try {
      final analysis = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'performanceReport': _performanceMonitor.getPerformanceReport(),
        'lazyLoadingStats': _lazyLoadingService.getCacheStatistics(),
        'imageCacheStats': await _imageCacheService.getDetailedCacheStatistics(),
        'recommendations': _performanceMonitor.getPerformanceRecommendations(),
      };
      
      // Add health assessment
      analysis['healthAssessment'] = _assessOverallHealth(analysis);
      
      return analysis;
    } catch (e) {
      developer.log('Error generating performance analysis: $e', name: 'PerformanceOptimization');
      return {
        'error': 'Failed to generate performance analysis: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Assess overall system health based on performance metrics
  Map<String, dynamic> _assessOverallHealth(Map<String, dynamic> analysis) {
    final issues = <String>[];
    final warnings = <String>[];
    
    try {
      // Check memory usage
      final memoryStats = analysis['performanceReport']['memoryStatistics'] as Map<String, dynamic>?;
      if (memoryStats != null) {
        final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
        if (currentUsage > 150) {
          issues.add('High memory usage: ${currentUsage.toStringAsFixed(1)}MB');
        } else if (currentUsage > 100) {
          warnings.add('Elevated memory usage: ${currentUsage.toStringAsFixed(1)}MB');
        }
      }
      
      // Check query performance
      final queryStats = analysis['performanceReport']['queryStatistics'] as Map<String, dynamic>?;
      if (queryStats != null) {
        int slowQueries = 0;
        for (final entry in queryStats.entries) {
          final stats = entry.value as Map<String, dynamic>;
          if (stats['p95Ms'] > 1000) {
            slowQueries++;
          }
        }
        
        if (slowQueries > 5) {
          issues.add('Multiple slow queries detected: $slowQueries queries > 1s');
        } else if (slowQueries > 2) {
          warnings.add('Some slow queries detected: $slowQueries queries > 1s');
        }
      }
      
      // Check image cache efficiency
      final imageCacheStats = analysis['imageCacheStats'] as Map<String, dynamic>?;
      if (imageCacheStats != null) {
        final utilization = imageCacheStats['cacheUtilization'] as double? ?? 0;
        final efficiency = imageCacheStats['storageEfficiency'] as double? ?? 1;
        
        if (utilization > 0.95) {
          issues.add('Image cache nearly full: ${(utilization * 100).toStringAsFixed(1)}%');
        }
        
        if (efficiency < 0.7) {
          warnings.add('Low image cache efficiency: ${(efficiency * 100).toStringAsFixed(1)}%');
        }
      }
      
      // Determine overall health status
      String status;
      if (issues.isNotEmpty) {
        status = 'critical';
      } else if (warnings.isNotEmpty) {
        status = 'warning';
      } else {
        status = 'healthy';
      }
      
      return {
        'status': status,
        'issues': issues,
        'warnings': warnings,
        'score': _calculateHealthScore(issues.length, warnings.length),
      };
    } catch (e) {
      return {
        'status': 'error',
        'issues': ['Failed to assess health: $e'],
        'warnings': [],
        'score': 0,
      };
    }
  }

  /// Calculate health score (0-100)
  int _calculateHealthScore(int issueCount, int warningCount) {
    int score = 100;
    score -= issueCount * 20; // Each issue reduces score by 20
    score -= warningCount * 10; // Each warning reduces score by 10
    return score.clamp(0, 100);
  }

  /// Perform comprehensive system optimization
  Future<void> performComprehensiveOptimization({
    DatabaseService? databaseService,
    SyncManager? syncManager,
  }) async {
    developer.log('Starting comprehensive optimization', name: 'PerformanceOptimization');
    
    try {
      // Optimize memory usage first
      await optimizeMemoryUsage();
      
      // Optimize database queries
      if (databaseService != null) {
        await optimizeDatabaseQueries(databaseService);
      }
      
      // Optimize sync operations
      if (syncManager != null) {
        await optimizeSyncOperations(syncManager);
      }
      
      // Perform image cache optimization
      await _imageCacheService.optimizeStorage();
      
      // Clear performance metrics to start fresh
      _performanceMonitor.clearMetrics();
      
      developer.log('Comprehensive optimization completed', name: 'PerformanceOptimization');
    } catch (e) {
      developer.log('Error during comprehensive optimization: $e', name: 'PerformanceOptimization');
    }
  }

  /// Get optimization recommendations based on current performance
  List<String> getOptimizationRecommendations() {
    final recommendations = <String>[];
    
    try {
      // Get base recommendations from performance monitor
      recommendations.addAll(_performanceMonitor.getPerformanceRecommendations());
      
      // Add service-specific recommendations
      final lazyLoadingStats = _lazyLoadingService.getCacheStatistics();
      if (lazyLoadingStats.isNotEmpty) {
        int totalCacheHits = 0;
        int totalCacheMisses = 0;
        
        for (final stats in lazyLoadingStats.values) {
          if (stats is Map<String, dynamic>) {
            totalCacheHits += (stats['cacheHits'] as int? ?? 0);
            totalCacheMisses += (stats['cacheMisses'] as int? ?? 0);
          }
        }
        
        if (totalCacheMisses > 0) {
          final hitRate = totalCacheHits / (totalCacheHits + totalCacheMisses);
          if (hitRate < 0.7) {
            recommendations.add('Low lazy loading cache hit rate (${(hitRate * 100).toStringAsFixed(1)}%). Consider preloading frequently accessed data.');
          }
        }
      }
      
      return recommendations;
    } catch (e) {
      developer.log('Error getting optimization recommendations: $e', name: 'PerformanceOptimization');
      return ['Error generating recommendations: $e'];
    }
  }

  /// Dispose resources
  void dispose() {
    _optimizationTimer?.cancel();
    _performanceMonitor.dispose();
    _lazyLoadingService.clearAllCaches();
    developer.log('Performance Optimization Service disposed', name: 'PerformanceOptimization');
  }
}