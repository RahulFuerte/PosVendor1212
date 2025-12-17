import 'dart:async';
import 'dart:developer' as developer;
import 'smart_preloading_service.dart';
import 'lazy_loading_service.dart';
import 'memory_management_service.dart';
import 'complete_offline_data_manager.dart';
import 'performance_monitor.dart';

/// Data preloading coordinator that orchestrates all preloading services
/// Implements intelligent coordination between different preloading strategies
class DataPreloadingCoordinator {
  static final DataPreloadingCoordinator _instance = DataPreloadingCoordinator._internal();
  factory DataPreloadingCoordinator() => _instance;
  DataPreloadingCoordinator._internal();

  SmartPreloadingService? _smartPreloadingService;
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();
  MemoryManagementService? _memoryManagementService;
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  Timer? _coordinationTimer;
  bool _isInitialized = false;
  
  // Coordination settings
  static const Duration _coordinationInterval = Duration(minutes: 5);
  static const int _maxConcurrentPreloads = 3;
  
  final Set<String> _activePreloads = {};
  final Map<String, DateTime> _lastPreloadAttempt = {};
  final Map<String, PreloadingStrategy> _userStrategies = {};

  /// Initialize the data preloading coordinator
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize services safely to avoid circular dependencies
      try {
        _smartPreloadingService = SmartPreloadingService();
        await _smartPreloadingService!.initialize();
      } catch (e) {
        developer.log('Warning: Could not initialize SmartPreloadingService: $e', name: 'DataPreloadingCoordinator');
        _smartPreloadingService = null;
      }
      
      try {
        _memoryManagementService = MemoryManagementService();
        await _memoryManagementService!.initialize();
      } catch (e) {
        developer.log('Warning: Could not initialize MemoryManagementService: $e', name: 'DataPreloadingCoordinator');
        _memoryManagementService = null;
      }
      
      await _offlineDataManager.initialize();
      
      _startCoordination();
      _isInitialized = true;
      
      developer.log('Data preloading coordinator initialized', name: 'DataPreloadingCoordinator');
    } catch (e) {
      developer.log('Error initializing data preloading coordinator: $e', name: 'DataPreloadingCoordinator');
      rethrow;
    }
  }

  /// Start coordination timer for periodic optimization
  void _startCoordination() {
    _coordinationTimer?.cancel();
    _coordinationTimer = Timer.periodic(_coordinationInterval, (timer) {
      _coordinatePreloadingStrategies();
    });
  }

  /// Coordinate different preloading strategies based on system state
  Future<void> _coordinatePreloadingStrategies() async {
    try {
      await _performanceMonitor.trackQuery('coordinate_preloading', () async {
        // Get current system state
        final memoryStats = _memoryManagementService != null 
            ? await _memoryManagementService!.getMemoryStatistics()
            : {'isLowMemoryMode': false};
        final isLowMemory = memoryStats['isLowMemoryMode'] as bool;
        
        developer.log('Coordinating preloading strategies - Low memory: $isLowMemory', 
                     name: 'DataPreloadingCoordinator');
        
        // Adjust strategies based on memory state
        if (isLowMemory) {
          await _implementConservativeStrategy();
        } else {
          await _implementAggressiveStrategy();
        }
        
        // Clean up old preload attempts
        _cleanupOldPreloadAttempts();
      });
    } catch (e) {
      developer.log('Error coordinating preloading strategies: $e', name: 'DataPreloadingCoordinator');
    }
  }

  /// Implement conservative preloading strategy for low memory situations
  Future<void> _implementConservativeStrategy() async {
    try {
      // Limit concurrent preloads
      if (_activePreloads.length >= 1) {
        developer.log('Limiting preloads due to low memory', name: 'DataPreloadingCoordinator');
        return;
      }
      
      // Focus only on essential data
      for (final entry in _userStrategies.entries) {
        final adminUid = entry.key;
        final strategy = entry.value;
        
        if (strategy.priority == PreloadingPriority.high) {
          await _executeEssentialPreloading(adminUid);
          break; // Only one high-priority preload in conservative mode
        }
      }
    } catch (e) {
      developer.log('Error in conservative preloading strategy: $e', name: 'DataPreloadingCoordinator');
    }
  }

  /// Implement aggressive preloading strategy for normal memory situations
  Future<void> _implementAggressiveStrategy() async {
    try {
      final futures = <Future>[];
      
      for (final entry in _userStrategies.entries) {
        if (_activePreloads.length >= _maxConcurrentPreloads) break;
        
        final adminUid = entry.key;
        final strategy = entry.value;
        
        // Skip if recently attempted
        final lastAttempt = _lastPreloadAttempt[adminUid];
        if (lastAttempt != null && 
            DateTime.now().difference(lastAttempt) < const Duration(minutes: 10)) {
          continue;
        }
        
        switch (strategy.priority) {
          case PreloadingPriority.high:
            futures.add(_executeEssentialPreloading(adminUid));
            break;
          case PreloadingPriority.medium:
            futures.add(_executePredictivePreloading(adminUid));
            break;
          case PreloadingPriority.low:
            futures.add(_executeOpportunisticPreloading(adminUid));
            break;
        }
      }
      
      // Execute preloads concurrently but with limits
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (e) {
      developer.log('Error in aggressive preloading strategy: $e', name: 'DataPreloadingCoordinator');
    }
  }

  /// Execute essential preloading (high priority)
  Future<void> _executeEssentialPreloading(String adminUid) async {
    final preloadKey = '${adminUid}_essential';
    if (_activePreloads.contains(preloadKey)) return;
    
    try {
      _activePreloads.add(preloadKey);
      _lastPreloadAttempt[adminUid] = DateTime.now();
      
      developer.log('Executing essential preloading for $adminUid', name: 'DataPreloadingCoordinator');
      
      // Preload only the most critical data
      await _offlineDataManager.preloadAllCriticalData(adminUid);
      
    } finally {
      _activePreloads.remove(preloadKey);
    }
  }

  /// Execute predictive preloading (medium priority)
  Future<void> _executePredictivePreloading(String adminUid) async {
    final preloadKey = '${adminUid}_predictive';
    if (_activePreloads.contains(preloadKey)) return;
    
    try {
      _activePreloads.add(preloadKey);
      _lastPreloadAttempt[adminUid] = DateTime.now();
      
      developer.log('Executing predictive preloading for $adminUid', name: 'DataPreloadingCoordinator');
      
      // Use smart preloading for predictive caching
      if (_smartPreloadingService != null) {
        await _smartPreloadingService!.implementPredictiveCaching(adminUid);
      }
      
    } finally {
      _activePreloads.remove(preloadKey);
    }
  }

  /// Execute opportunistic preloading (low priority)
  Future<void> _executeOpportunisticPreloading(String adminUid) async {
    final preloadKey = '${adminUid}_opportunistic';
    if (_activePreloads.contains(preloadKey)) return;
    
    try {
      _activePreloads.add(preloadKey);
      _lastPreloadAttempt[adminUid] = DateTime.now();
      
      developer.log('Executing opportunistic preloading for $adminUid', name: 'DataPreloadingCoordinator');
      
      // Preload frequently accessed items
      if (_smartPreloadingService != null) {
        await _smartPreloadingService!.preloadFrequentlyAccessedItems(adminUid);
      }
      
    } finally {
      _activePreloads.remove(preloadKey);
    }
  }

  /// Set preloading strategy for a user
  void setUserPreloadingStrategy(String adminUid, PreloadingStrategy strategy) {
    _userStrategies[adminUid] = strategy;
    developer.log('Set preloading strategy for $adminUid: ${strategy.priority}', 
                 name: 'DataPreloadingCoordinator');
  }

  /// Track user interaction to adjust preloading strategy
  Future<void> trackUserInteraction(String adminUid, UserInteractionType interactionType, 
                                   {String? department, String? itemId}) async {
    await _ensureInitialized();
    
    try {
      // Update user strategy based on interaction patterns
      _updateUserStrategy(adminUid, interactionType);
      
      // Track with smart preloading service
      switch (interactionType) {
        case UserInteractionType.departmentAccess:
          if (department != null && _smartPreloadingService != null) {
            await _smartPreloadingService!.trackDepartmentAccess(adminUid, department);
          }
          break;
        case UserInteractionType.itemAccess:
          if (itemId != null && department != null && _smartPreloadingService != null) {
            await _smartPreloadingService!.trackItemAccess(adminUid, itemId, department);
          }
          break;
        case UserInteractionType.search:
          // Increase preloading priority for search-heavy users
          _adjustStrategyForSearchUser(adminUid);
          break;
        case UserInteractionType.billCreation:
          // Ensure bill-related data is preloaded
          _adjustStrategyForBillingUser(adminUid);
          break;
        case UserInteractionType.navigation:
          // Handle navigation interactions
          break;
      }
    } catch (e) {
      developer.log('Error tracking user interaction: $e', name: 'DataPreloadingCoordinator');
    }
  }

  /// Trigger immediate preloading for a user
  Future<void> triggerImmediatePreloading(String adminUid, {String? department}) async {
    await _ensureInitialized();
    
    try {
      developer.log('Triggering immediate preloading for $adminUid', name: 'DataPreloadingCoordinator');
      
      // Execute based on current memory state
      if (_memoryManagementService?.isLowMemoryMode == true) {
        await _executeEssentialPreloading(adminUid);
      } else {
        // Execute multiple strategies concurrently
        final futures = [
          _executeEssentialPreloading(adminUid),
          _executePredictivePreloading(adminUid),
        ];
        
        if (department != null && _smartPreloadingService != null) {
          futures.add(_smartPreloadingService!.preloadDepartmentItems(adminUid, department));
        }
        
        await Future.wait(futures);
      }
    } catch (e) {
      developer.log('Error in immediate preloading: $e', name: 'DataPreloadingCoordinator');
    }
  }

  /// Get comprehensive preloading statistics
  Future<Map<String, dynamic>> getPreloadingStatistics() async {
    final memoryStats = _memoryManagementService != null 
        ? await _memoryManagementService!.getMemoryStatistics()
        : {'isLowMemoryMode': false};
    final smartPreloadingStats = _smartPreloadingService?.getPreloadingStatistics() ?? {};
    final lazyLoadingStats = _lazyLoadingService.getCacheStatistics();
    
    return {
      'coordinator': {
        'activePreloads': _activePreloads.length,
        'userStrategies': _userStrategies.length,
        'lastPreloadAttempts': _lastPreloadAttempt.length,
      },
      'memoryManagement': memoryStats,
      'smartPreloading': smartPreloadingStats,
      'lazyLoading': lazyLoadingStats,
      'isLowMemoryMode': _memoryManagementService?.isLowMemoryMode ?? false,
    };
  }

  // Private helper methods

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  void _updateUserStrategy(String adminUid, UserInteractionType interactionType) {
    final currentStrategy = _userStrategies[adminUid] ?? 
        PreloadingStrategy(priority: PreloadingPriority.medium);
    
    // Adjust strategy based on interaction frequency
    currentStrategy.recordInteraction(interactionType);
    
    // Update priority based on interaction patterns
    if (currentStrategy.getInteractionFrequency() > 10) {
      currentStrategy.priority = PreloadingPriority.high;
    } else if (currentStrategy.getInteractionFrequency() > 5) {
      currentStrategy.priority = PreloadingPriority.medium;
    } else {
      currentStrategy.priority = PreloadingPriority.low;
    }
    
    _userStrategies[adminUid] = currentStrategy;
  }

  void _adjustStrategyForSearchUser(String adminUid) {
    final strategy = _userStrategies[adminUid] ?? 
        PreloadingStrategy(priority: PreloadingPriority.medium);
    strategy.isSearchHeavyUser = true;
    _userStrategies[adminUid] = strategy;
  }

  void _adjustStrategyForBillingUser(String adminUid) {
    final strategy = _userStrategies[adminUid] ?? 
        PreloadingStrategy(priority: PreloadingPriority.medium);
    strategy.isBillingHeavyUser = true;
    _userStrategies[adminUid] = strategy;
  }

  void _cleanupOldPreloadAttempts() {
    final now = DateTime.now();
    final oldKeys = <String>[];
    
    for (final entry in _lastPreloadAttempt.entries) {
      if (now.difference(entry.value) > const Duration(hours: 1)) {
        oldKeys.add(entry.key);
      }
    }
    
    for (final key in oldKeys) {
      _lastPreloadAttempt.remove(key);
    }
  }

  /// Dispose resources and stop coordination
  void dispose() {
    _coordinationTimer?.cancel();
    _activePreloads.clear();
    _lastPreloadAttempt.clear();
    _userStrategies.clear();
    _memoryManagementService?.dispose();
    _smartPreloadingService?.dispose();
    _isInitialized = false;
    
    developer.log('Data preloading coordinator disposed', name: 'DataPreloadingCoordinator');
  }
}

/// Preloading strategy configuration
class PreloadingStrategy {
  PreloadingPriority priority;
  bool isSearchHeavyUser;
  bool isBillingHeavyUser;
  final Map<UserInteractionType, int> _interactionCounts = {};
  DateTime lastUpdated = DateTime.now();

  PreloadingStrategy({
    required this.priority,
    this.isSearchHeavyUser = false,
    this.isBillingHeavyUser = false,
  });

  void recordInteraction(UserInteractionType type) {
    _interactionCounts[type] = (_interactionCounts[type] ?? 0) + 1;
    lastUpdated = DateTime.now();
  }

  int getInteractionFrequency() {
    return _interactionCounts.values.fold(0, (sum, count) => sum + count);
  }

  int getInteractionCount(UserInteractionType type) {
    return _interactionCounts[type] ?? 0;
  }
}

/// Preloading priority levels
enum PreloadingPriority {
  low,
  medium,
  high,
}

/// User interaction types for tracking
enum UserInteractionType {
  departmentAccess,
  itemAccess,
  search,
  billCreation,
  navigation,
}