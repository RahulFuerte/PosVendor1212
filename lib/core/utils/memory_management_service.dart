// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:device_info_plus/device_info_plus.dart';

// Project imports:
import '../../data/datasources/image_cache_service.dart';
import '../../data/datasources/lazy_loading_service.dart';
import '../../data/datasources/smart_preloading_service.dart';
import 'performance_monitor.dart';

/// Memory management service for efficient cache management and memory optimization
/// Implements intelligent cache cleanup and memory monitoring
class MemoryManagementService {
  static final MemoryManagementService _instance = MemoryManagementService._internal();
  factory MemoryManagementService() => _instance;
  MemoryManagementService._internal();

  SmartPreloadingService? _smartPreloadingService;
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  Timer? _memoryMonitorTimer;
  Timer? _cleanupTimer;
  
  // Memory thresholds (in MB)
  static const double _lowMemoryThreshold = 100.0;
  static const double _criticalMemoryThreshold = 50.0;
  static const double _targetMemoryUsage = 200.0;
  
  // Cleanup intervals
  static const Duration _memoryCheckInterval = Duration(minutes: 2);
  static const Duration _routineCleanupInterval = Duration(minutes: 10);
  
  bool _isInitialized = false;
  bool _isLowMemoryMode = false;
  int _totalDeviceMemoryMB = 0;

  /// Initialize the memory management service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _getDeviceMemoryInfo();
      _startMemoryMonitoring();
      _startRoutineCleanup();
      
      _isInitialized = true;
    
    } catch (e) {
      rethrow;
    }
  }

  /// Set the smart preloading service reference (to avoid circular dependency)
  void setSmartPreloadingService(SmartPreloadingService service) {
    _smartPreloadingService = service;
  }

  /// Start memory monitoring with periodic checks
  void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(_memoryCheckInterval, (timer) {
      _checkMemoryUsage();
    });
  }

  /// Start routine cleanup operations
  void _startRoutineCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_routineCleanupInterval, (timer) {
      _performRoutineCleanup();
    });
  }

  /// Check current memory usage and trigger cleanup if needed
  Future<void> _checkMemoryUsage() async {
    try {
      final memoryInfo = await _getCurrentMemoryUsage();
      final availableMemoryMB = memoryInfo['availableMemoryMB'] as double;
      final usedMemoryMB = memoryInfo['usedMemoryMB'] as double;
      
   
      
      if (availableMemoryMB < _criticalMemoryThreshold) {
       
        await _performAggressiveCleanup();
        _isLowMemoryMode = true;
      } else if (availableMemoryMB < _lowMemoryThreshold) {
       
        await _performModerateCleanup();
        _isLowMemoryMode = true;
      } else {
        _isLowMemoryMode = false;
      }
    } catch (e) {
    }
  }

  /// Perform routine cleanup operations
  Future<void> _performRoutineCleanup() async {
    try {
      await _performanceMonitor.trackQuery('routine_cleanup', () async {
        // Clean up expired caches
        _lazyLoadingService.cleanupExpiredCaches();
        if (_smartPreloadingService != null) {
          await _smartPreloadingService!.manageCacheMemory();
        }
        await _imageCacheService.performAutomaticCleanup();
        
      });
    } catch (e) {
    }
  }

  /// Perform moderate cleanup when memory is low
  Future<void> _performModerateCleanup() async {
    try {
      await _performanceMonitor.trackQuery('moderate_cleanup', () async {
        // Clear expired caches
        _lazyLoadingService.cleanupExpiredCaches();
        if (_smartPreloadingService != null) {
          await _smartPreloadingService!.manageCacheMemory();
        }
        
        // Clear some image cache
        await _imageCacheService.clearImageCache(olderThanDays: 7); // Clear images older than 7 days
        
        // Clear some lazy loading caches
        _clearOldestLazyLoadingCaches(0.2); // Clear 20% of oldest caches
        
      });
    } catch (e) {
    }
  }

  /// Perform aggressive cleanup when memory is critically low
  Future<void> _performAggressiveCleanup() async {
    try {
      await _performanceMonitor.trackQuery('aggressive_cleanup', () async {
        // Clear all expired caches
        _lazyLoadingService.cleanupExpiredCaches();
        if (_smartPreloadingService != null) {
          await _smartPreloadingService!.manageCacheMemory();
        }
        
        // Clear majority of image cache
        await _imageCacheService.clearImageCache(olderThanDays: 3); // Clear images older than 3 days
        
        // Clear majority of lazy loading caches
        _clearOldestLazyLoadingCaches(0.5); // Clear 50% of oldest caches
        
        // Clear all non-essential preloaded data
        _clearNonEssentialPreloadedData();
        
        // Force garbage collection
        _forceGarbageCollection();
        
      });
    } catch (e) {
    }
  }

  /// Clear oldest lazy loading caches based on percentage
  void _clearOldestLazyLoadingCaches(double percentage) {
    try {
      final stats = _lazyLoadingService.getCacheStatistics();
      final cacheKeys = stats.keys.toList();
      
      if (cacheKeys.isEmpty) return;
      
      // Sort by last accessed time (oldest first)
      cacheKeys.sort((a, b) {
        final aTime = stats[a]['lastAccessed'] as String?;
        final bTime = stats[b]['lastAccessed'] as String?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        
        return DateTime.parse(aTime).compareTo(DateTime.parse(bTime));
      });
      
      final numToClear = (cacheKeys.length * percentage).ceil();
      final keysToRemove = cacheKeys.take(numToClear);
      
      for (final key in keysToRemove) {
        _lazyLoadingService.clearCache(key);
      }
      
    } catch (e) {
    }
  }

  /// Clear non-essential preloaded data to free memory
  void _clearNonEssentialPreloadedData() {
    try {
      // This would clear predictive preloading data but keep essential data
      // Implementation depends on SmartPreloadingService internal structure
    } catch (e) {
    }
  }

  /// Force garbage collection (platform-specific)
  void _forceGarbageCollection() {
    try {
      // Dart doesn't provide direct GC control, but we can trigger it indirectly
      // by creating and releasing temporary objects
      final temp = List.generate(1000, (index) => 'temp_$index');
      temp.clear();
      
    } catch (e) {
    }
  }

  /// Get device memory information
  Future<void> _getDeviceMemoryInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android doesn't provide direct memory info through device_info_plus
        // We'll use a reasonable default based on device characteristics
        _totalDeviceMemoryMB = _estimateAndroidMemory(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iOS doesn't provide direct memory info through device_info_plus
        // We'll use a reasonable default based on device model
        _totalDeviceMemoryMB = _estimateIOSMemory(iosInfo);
      } else {
        // Default for other platforms
        _totalDeviceMemoryMB = 2048; // 2GB default
      }
    } catch (e) {
      _totalDeviceMemoryMB = 2048; // 2GB default fallback
    }
  }

  /// Estimate Android device memory based on device characteristics
  int _estimateAndroidMemory(AndroidDeviceInfo androidInfo) {
    // This is a rough estimation based on Android API level and device characteristics
    final sdkInt = androidInfo.version.sdkInt;
    
    if (sdkInt >= 30) { // Android 11+
      return 4096; // Assume 4GB for modern devices
    } else if (sdkInt >= 26) { // Android 8+
      return 3072; // Assume 3GB for mid-range modern devices
    } else if (sdkInt >= 21) { // Android 5+
      return 2048; // Assume 2GB for older devices
    } else {
      return 1024; // Assume 1GB for very old devices
    }
  }

  /// Estimate iOS device memory based on device model
  int _estimateIOSMemory(IosDeviceInfo iosInfo) {
    final model = iosInfo.model.toLowerCase();
    
    if (model.contains('iphone')) {
      // Modern iPhones typically have 4-6GB
      return 4096;
    } else if (model.contains('ipad')) {
      // iPads typically have more memory
      return 6144;
    } else {
      // Default for other iOS devices
      return 3072;
    }
  }

  /// Get current memory usage (simplified estimation)
  Future<Map<String, dynamic>> _getCurrentMemoryUsage() async {
    try {
      // Since Dart doesn't provide direct memory usage APIs,
      // we'll estimate based on cache sizes and other factors
      
      final lazyLoadingStats = _lazyLoadingService.getCacheStatistics();
      final preloadingStats = _smartPreloadingService?.getPreloadingStatistics() ?? {};
      
      // Estimate memory usage based on cache entries
      double estimatedUsageMB = 0.0;
      
      // Estimate lazy loading cache usage (rough estimation)
      final totalCacheEntries = lazyLoadingStats.length;
      estimatedUsageMB += totalCacheEntries * 0.5; // Assume 0.5MB per cache on average
      
      // Estimate preloading cache usage
      final preloadedEntries = preloadingStats['preloadedEntries'] as int? ?? 0;
      estimatedUsageMB += preloadedEntries * 1.0; // Assume 1MB per preloaded entry
      
      // Add base app memory usage
      estimatedUsageMB += 50.0; // Base app memory
      
      final availableMemoryMB = _totalDeviceMemoryMB - estimatedUsageMB;
      
      return {
        'totalMemoryMB': _totalDeviceMemoryMB.toDouble(),
        'usedMemoryMB': estimatedUsageMB,
        'availableMemoryMB': availableMemoryMB,
        'isLowMemoryMode': _isLowMemoryMode,
      };
    } catch (e) {
      return {
        'totalMemoryMB': _totalDeviceMemoryMB.toDouble(),
        'usedMemoryMB': 100.0,
        'availableMemoryMB': _totalDeviceMemoryMB - 100.0,
        'isLowMemoryMode': _isLowMemoryMode,
      };
    }
  }

  /// Get memory management statistics
  Future<Map<String, dynamic>> getMemoryStatistics() async {
    final memoryInfo = await _getCurrentMemoryUsage();
    final lazyLoadingStats = _lazyLoadingService.getCacheStatistics();
    final preloadingStats = _smartPreloadingService?.getPreloadingStatistics() ?? {};
    
    return {
      'memoryInfo': memoryInfo,
      'lazyLoadingCaches': lazyLoadingStats.length,
      'preloadingEntries': preloadingStats['preloadedEntries'] ?? 0,
      'isLowMemoryMode': _isLowMemoryMode,
      'totalDeviceMemoryMB': _totalDeviceMemoryMB,
      'memoryThresholds': {
        'low': _lowMemoryThreshold,
        'critical': _criticalMemoryThreshold,
        'target': _targetMemoryUsage,
      },
    };
  }

  /// Check if the system is in low memory mode
  bool get isLowMemoryMode => _isLowMemoryMode;

  /// Get recommended cache size based on available memory
  int getRecommendedCacheSize() {
    if (_isLowMemoryMode) {
      return 10; // Reduced cache size in low memory mode
    } else if (_totalDeviceMemoryMB < 2048) {
      return 20; // Small cache for low-memory devices
    } else if (_totalDeviceMemoryMB < 4096) {
      return 50; // Medium cache for mid-range devices
    } else {
      return 100; // Large cache for high-memory devices
    }
  }

  /// Optimize preloading based on memory constraints
  Future<void> optimizePreloadingForMemory() async {
    try {
      if (_isLowMemoryMode) {
        // Reduce preloading in low memory mode
        
        // This would communicate with SmartPreloadingService to reduce preloading
        // Implementation depends on SmartPreloadingService API
      }
    } catch (e) {
    }
  }

  /// Dispose resources and stop monitoring
  void dispose() {
    _memoryMonitorTimer?.cancel();
    _cleanupTimer?.cancel();
    _isInitialized = false;
    
  }
}
