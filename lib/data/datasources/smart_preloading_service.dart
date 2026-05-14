// Dart imports:
import 'dart:async';
import 'dart:math';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import '../../core/utils/memory_management_service.dart';
import '../../core/utils/performance_monitor.dart';
import 'complete_offline_data_manager.dart';
import 'lazy_loading_service.dart';


/// Smart preloading service that implements intelligent data preloading based on user patterns
/// Implements predictive caching and department-specific item preloading
class SmartPreloadingService {
  static final SmartPreloadingService _instance = SmartPreloadingService._internal();
  factory SmartPreloadingService() => _instance;
  SmartPreloadingService._internal();

  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();
  late final MemoryManagementService _memoryManagementService;
  
  // User behavior tracking
  final Map<String, UserBehaviorPattern> _userPatterns = {};
  final Map<String, List<String>> _departmentAccessHistory = {};
  final Map<String, int> _itemAccessCount = {};
  final Map<String, DateTime> _lastAccessTime = {};
  
  // Preloading state
  final Set<String> _preloadingInProgress = {};
  final Map<String, DateTime> _preloadedAt = {};
  
  // Configuration
  static const int _maxPreloadItems = 50;
  static const int _maxDepartmentHistory = 10;
  static const Duration _preloadExpiry = Duration(hours: 2);
  static const double _preloadThreshold = 0.3; // 30% access frequency threshold
  
  bool _isInitialized = false;

  /// Initialize the smart preloading service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadUserPatterns();
      await _offlineDataManager.initialize();
      
      // Initialize memory management service and set up circular reference
      _memoryManagementService = MemoryManagementService();
      await _memoryManagementService.initialize();
      _memoryManagementService.setSmartPreloadingService(this);
      
      _isInitialized = true;
      
    } catch (e) {
      rethrow;
    }
  }

  /// Track user access to departments for pattern analysis
  Future<void> trackDepartmentAccess(String adminUid, String department) async {
    await _ensureInitialized();
    
    final key = '${adminUid}_departments';
    _departmentAccessHistory[key] ??= [];
    
    // Add to history and limit size
    _departmentAccessHistory[key]!.insert(0, department);
    if (_departmentAccessHistory[key]!.length > _maxDepartmentHistory) {
      _departmentAccessHistory[key] = _departmentAccessHistory[key]!.take(_maxDepartmentHistory).toList();
    }
    
    // Update access time
    _lastAccessTime['${adminUid}_dept_$department'] = DateTime.now();
    
    // Save patterns
    await _saveUserPatterns();
    
    // Trigger predictive preloading
    _triggerPredictivePreloading(adminUid, department);
    
  }

  /// Track user access to food items for pattern analysis
  Future<void> trackItemAccess(String adminUid, String itemId, String department) async {
    await _ensureInitialized();
    
    final key = '${adminUid}_item_$itemId';
    _itemAccessCount[key] = (_itemAccessCount[key] ?? 0) + 1;
    _lastAccessTime[key] = DateTime.now();
    
    // Update user behavior pattern
    _updateUserBehaviorPattern(adminUid, department, itemId);
    
    // Save patterns
    await _saveUserPatterns();
    
  }

  /// Preload frequently accessed food items based on user patterns
  Future<void> preloadFrequentlyAccessedItems(String adminUid) async {
    await _ensureInitialized();
    
    final preloadKey = '${adminUid}_frequent_items';
    if (_preloadingInProgress.contains(preloadKey)) {
      
      return;
    }
    
    try {
      _preloadingInProgress.add(preloadKey);
      
      await _performanceMonitor.trackQuery('preload_frequent_items', () async {
        // Check memory constraints before preloading
        if (_memoryManagementService.isLowMemoryMode) {
          
          return;
        }
        
        // Get frequently accessed items
        final frequentItems = _getFrequentlyAccessedItems(adminUid);
        
        if (frequentItems.isNotEmpty) {
          // Adjust batch size based on memory constraints
          final recommendedCacheSize = _memoryManagementService.getRecommendedCacheSize();
          final maxItemsToPreload = min(frequentItems.length, recommendedCacheSize);
          final itemsToPreload = frequentItems.take(maxItemsToPreload).toList();
          
          
          // Preload items in batches to avoid overwhelming the system
          final batchSize = _memoryManagementService.isLowMemoryMode ? 5 : 10;
          for (int i = 0; i < itemsToPreload.length; i += batchSize) {
            final batch = itemsToPreload.skip(i).take(batchSize).toList();
            await _preloadItemBatch(adminUid, batch);
            
            // Longer delay in low memory mode
            final delay = _memoryManagementService.isLowMemoryMode ? 200 : 100;
            await Future.delayed(Duration(milliseconds: delay));
          }
          
          _preloadedAt[preloadKey] = DateTime.now();
          
        }
      });
    } finally {
      _preloadingInProgress.remove(preloadKey);
    }
  }

  /// Preload items for a specific department
  Future<void> preloadDepartmentItems(String adminUid, String department) async {
    await _ensureInitialized();
    
    final preloadKey = '${adminUid}_dept_$department';
    if (_preloadingInProgress.contains(preloadKey)) {
      
      return;
    }
    
    try {
      _preloadingInProgress.add(preloadKey);
      
      await _performanceMonitor.trackQuery('preload_department_items', () async {
        // Get all items for the department
        final items = await _offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid, department: department);
        
        if (items.isNotEmpty) {
          
          
          // Create lazy loader for this department
          final loader = _lazyLoadingService.createLoader<Map<String, dynamic>>(
            cacheKey: 'dept_items_${adminUid}_$department',
            pageSize: 20,
            itemIdExtractor: (item) => item['id'] as String,
            dataFetcher: (offset, limit) async {
              final endIndex = (offset + limit).clamp(0, items.length);
              return items.sublist(offset.clamp(0, items.length), endIndex);
            },
          );
          
          // Preload first few pages
          final pagesToPreload = (items.length / 20).ceil().clamp(1, 3);
          final pageIndices = List.generate(pagesToPreload, (index) => index);
          await loader.preloadPages(pageIndices);
          
          _preloadedAt[preloadKey] = DateTime.now();
          
        }
      });
    } finally {
      _preloadingInProgress.remove(preloadKey);
    }
  }

  /// Implement predictive caching based on user behavior patterns
  Future<void> implementPredictiveCaching(String adminUid) async {
    await _ensureInitialized();
    
    try {
      await _performanceMonitor.trackQuery('predictive_caching', () async {
        final pattern = _userPatterns[adminUid];
        if (pattern == null) {
          
          return;
        }
        
        // Predict next likely departments based on patterns
        final predictedDepartments = _predictNextDepartments(adminUid);
        
        // Preload items for predicted departments
        for (final department in predictedDepartments) {
          await preloadDepartmentItems(adminUid, department);
          
          // Small delay between departments
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        // Preload frequently accessed items
        await preloadFrequentlyAccessedItems(adminUid);
        
      });
    } catch (e) {
    }
  }

  /// Manage cache memory efficiently by removing old entries
  Future<void> manageCacheMemory() async {
    await _ensureInitialized();
    
    try {
      final now = DateTime.now();
      final expiredKeys = <String>[];
      
      // Find expired preloaded data
      for (final entry in _preloadedAt.entries) {
        if (now.difference(entry.value) > _preloadExpiry) {
          expiredKeys.add(entry.key);
        }
      }
      
      // Clear expired preloaded data
      for (final key in expiredKeys) {
        _preloadedAt.remove(key);
        
        // Clear corresponding lazy loading cache
        if (key.contains('_dept_')) {
          final parts = key.split('_dept_');
          if (parts.length == 2) {
            final adminUid = parts[0];
            final department = parts[1];
            _lazyLoadingService.clearCache('dept_items_${adminUid}_$department');
          }
        }
      }
      
      // Clean up old access patterns
      _cleanupOldAccessPatterns();
      
      // Clean up lazy loading caches
      _lazyLoadingService.cleanupExpiredCaches();
      
      // Trigger memory management service cleanup if needed
      if (_memoryManagementService.isLowMemoryMode) {
        await _memoryManagementService.optimizePreloadingForMemory();
      }
      
      if (expiredKeys.isNotEmpty) {
        
      }
    } catch (e) {
      
    }
  }

  /// Get preloading statistics for monitoring
  Map<String, dynamic> getPreloadingStatistics() {
    final stats = <String, dynamic>{
      'userPatterns': _userPatterns.length,
      'departmentHistories': _departmentAccessHistory.length,
      'itemAccessCounts': _itemAccessCount.length,
      'preloadingInProgress': _preloadingInProgress.length,
      'preloadedEntries': _preloadedAt.length,
      'lazyLoadingStats': _lazyLoadingService.getCacheStatistics(),
    };
    
    // Add detailed user pattern stats
    final patternStats = <String, dynamic>{};
    for (final entry in _userPatterns.entries) {
      patternStats[entry.key] = {
        'departmentPreferences': entry.value.departmentPreferences.length,
        'itemPreferences': entry.value.itemPreferences.length,
        'lastUpdated': entry.value.lastUpdated.toIso8601String(),
      };
    }
    stats['patternDetails'] = patternStats;
    
    return stats;
  }

  /// Check if data is already preloaded and fresh
  bool isDataPreloaded(String adminUid, String dataType, {String? department}) {
    final key = department != null 
        ? '${adminUid}_dept_$department'
        : '${adminUid}_$dataType';
    
    final preloadedAt = _preloadedAt[key];
    if (preloadedAt == null) return false;
    
    return DateTime.now().difference(preloadedAt) < _preloadExpiry;
  }

  // Private helper methods

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  void _updateUserBehaviorPattern(String adminUid, String department, String itemId) {
    _userPatterns[adminUid] ??= UserBehaviorPattern(adminUid);
    final pattern = _userPatterns[adminUid]!;
    
    // Update department preferences
    pattern.departmentPreferences[department] = (pattern.departmentPreferences[department] ?? 0) + 1;
    
    // Update item preferences
    pattern.itemPreferences[itemId] = (pattern.itemPreferences[itemId] ?? 0) + 1;
    
    pattern.lastUpdated = DateTime.now();
  }

  List<String> _getFrequentlyAccessedItems(String adminUid) {
    final frequentItems = <String>[];
    final threshold = _calculateAccessThreshold(adminUid);
    
    for (final entry in _itemAccessCount.entries) {
      if (entry.key.startsWith('${adminUid}_item_') && entry.value >= threshold) {
        final itemId = entry.key.substring('${adminUid}_item_'.length);
        frequentItems.add(itemId);
      }
    }
    
    // Sort by access count (descending) and limit
    frequentItems.sort((a, b) {
      final countA = _itemAccessCount['${adminUid}_item_$a'] ?? 0;
      final countB = _itemAccessCount['${adminUid}_item_$b'] ?? 0;
      return countB.compareTo(countA);
    });
    
    return frequentItems.take(_maxPreloadItems).toList();
  }

  int _calculateAccessThreshold(String adminUid) {
    final userItemCounts = _itemAccessCount.entries
        .where((entry) => entry.key.startsWith('${adminUid}_item_'))
        .map((entry) => entry.value)
        .toList();
    
    if (userItemCounts.isEmpty) return 1;
    
    final maxCount = userItemCounts.reduce(max);
    return (maxCount * _preloadThreshold).ceil().clamp(1, maxCount);
  }

  List<String> _predictNextDepartments(String adminUid) {
    final key = '${adminUid}_departments';
    final history = _departmentAccessHistory[key];
    
    if (history == null || history.isEmpty) return [];
    
    // Simple prediction based on recent access patterns
    final recentDepartments = history.take(5).toSet().toList();
    
    // Add departments from user behavior pattern
    final pattern = _userPatterns[adminUid];
    if (pattern != null) {
      final preferredDepartments = pattern.departmentPreferences.entries
          .where((entry) => entry.value > 1)
          .map((entry) => entry.key)
          .toList();
      
      recentDepartments.addAll(preferredDepartments);
    }
    
    return recentDepartments.take(3).toList(); // Limit to top 3 predictions
  }

  Future<void> _preloadItemBatch(String adminUid, List<String> itemIds) async {
    try {
      // This would typically involve ensuring these specific items are cached
      // For now, we'll use the existing offline data manager
      await _offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
    } catch (e) {
      
    }
  }

  void _triggerPredictivePreloading(String adminUid, String currentDepartment) {
    // Trigger predictive preloading in background (non-blocking)
    Future.microtask(() async {
      try {
        // Preload current department items
        await preloadDepartmentItems(adminUid, currentDepartment);
        
        // Predict and preload next likely departments
        final predictedDepartments = _predictNextDepartments(adminUid);
        for (final department in predictedDepartments) {
          if (department != currentDepartment) {
            await preloadDepartmentItems(adminUid, department);
          }
        }
      } catch (e) {
        
      }
    });
  }

  void _cleanupOldAccessPatterns() {
    final now = DateTime.now();
    final oldKeys = <String>[];
    
    // Remove access times older than 30 days
    for (final entry in _lastAccessTime.entries) {
      if (now.difference(entry.value) > const Duration(days: 30)) {
        oldKeys.add(entry.key);
      }
    }
    
    for (final key in oldKeys) {
      _lastAccessTime.remove(key);
      if (key.contains('_item_')) {
        _itemAccessCount.remove(key);
      }
    }
  }

  Future<void> _loadUserPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load department access history
      final deptHistoryKeys = prefs.getKeys().where((key) => key.startsWith('dept_history_'));
      for (final key in deptHistoryKeys) {
        final history = prefs.getStringList(key);
        if (history != null) {
          final adminUid = key.substring('dept_history_'.length);
          _departmentAccessHistory['${adminUid}_departments'] = history;
        }
      }
      
      // Load item access counts
      final itemCountKeys = prefs.getKeys().where((key) => key.startsWith('item_count_'));
      for (final key in itemCountKeys) {
        final count = prefs.getInt(key);
        if (count != null) {
          final itemKey = key.substring('item_count_'.length);
          _itemAccessCount[itemKey] = count;
        }
      }
      
      // Load last access times
      final accessTimeKeys = prefs.getKeys().where((key) => key.startsWith('access_time_'));
      for (final key in accessTimeKeys) {
        final timeStr = prefs.getString(key);
        if (timeStr != null) {
          final accessKey = key.substring('access_time_'.length);
          _lastAccessTime[accessKey] = DateTime.parse(timeStr);
        }
      }
      
    } catch (e) {
      
    }
  }

  Future<void> _saveUserPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save department access history
      for (final entry in _departmentAccessHistory.entries) {
        final key = 'dept_history_${entry.key.replaceAll('_departments', '')}';
        await prefs.setStringList(key, entry.value);
      }
      
      // Save item access counts
      for (final entry in _itemAccessCount.entries) {
        final key = 'item_count_${entry.key}';
        await prefs.setInt(key, entry.value);
      }
      
      // Save last access times
      for (final entry in _lastAccessTime.entries) {
        final key = 'access_time_${entry.key}';
        await prefs.setString(key, entry.value.toIso8601String());
      }
    } catch (e) {
      
    }
  }

  /// Dispose resources and clear caches
  void dispose() {
    _userPatterns.clear();
    _departmentAccessHistory.clear();
    _itemAccessCount.clear();
    _lastAccessTime.clear();
    _preloadingInProgress.clear();
    _preloadedAt.clear();
    _isInitialized = false;
  }
}

/// User behavior pattern data class
class UserBehaviorPattern {
  final String adminUid;
  final Map<String, int> departmentPreferences = {};
  final Map<String, int> itemPreferences = {};
  DateTime lastUpdated = DateTime.now();

  UserBehaviorPattern(this.adminUid);

  Map<String, dynamic> toJson() {
    return {
      'adminUid': adminUid,
      'departmentPreferences': departmentPreferences,
      'itemPreferences': itemPreferences,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserBehaviorPattern.fromJson(Map<String, dynamic> json) {
    final pattern = UserBehaviorPattern(json['adminUid']);
    pattern.departmentPreferences.addAll(Map<String, int>.from(json['departmentPreferences'] ?? {}));
    pattern.itemPreferences.addAll(Map<String, int>.from(json['itemPreferences'] ?? {}));
    pattern.lastUpdated = DateTime.parse(json['lastUpdated']);
    return pattern;
  }
}
