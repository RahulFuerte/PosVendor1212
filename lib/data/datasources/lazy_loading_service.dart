// Dart imports:
import 'dart:async';
import 'dart:developer' as developer;

// Project imports:
import '../../core/utils/performance_monitor.dart';
import 'database_service.dart';


/// Lazy loading service for efficient data pagination and memory management
/// Implements virtual scrolling and on-demand data loading
class LazyLoadingService {
  static final LazyLoadingService _instance = LazyLoadingService._internal();
  factory LazyLoadingService() => _instance;
  LazyLoadingService._internal();

  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final Map<String, LazyDataCache> _caches = {};
  
  static const int _defaultPageSize = 20;
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Create a lazy loader for a specific data type
  LazyDataLoader<T> createLoader<T>({
    required String cacheKey,
    required Future<List<T>> Function(int offset, int limit) dataFetcher,
    required String Function(T item) itemIdExtractor,
    int pageSize = _defaultPageSize,
  }) {
    return LazyDataLoader<T>(
      cacheKey: cacheKey,
      dataFetcher: dataFetcher,
      itemIdExtractor: itemIdExtractor,
      pageSize: pageSize,
      lazyLoadingService: this,
    );
  }

  /// Get or create cache for a specific key
  LazyDataCache _getCache(String key) {
    if (!_caches.containsKey(key)) {
      _caches[key] = LazyDataCache(key);
    }
    return _caches[key]!;
  }

  /// Clear cache for a specific key
  void clearCache(String key) {
    _caches.remove(key);
    developer.log('Cleared lazy loading cache: $key', name: 'LazyLoadingService');
  }

  /// Clear all caches
  void clearAllCaches() {
    _caches.clear();
    developer.log('Cleared all lazy loading caches', name: 'LazyLoadingService');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final stats = <String, dynamic>{};
    
    for (final entry in _caches.entries) {
      final cache = entry.value;
      stats[entry.key] = {
        'totalItems': cache.totalItems,
        'loadedPages': cache.loadedPages.length,
        'cacheHits': cache.cacheHits,
        'cacheMisses': cache.cacheMisses,
        'lastAccessed': cache.lastAccessed?.toIso8601String(),
        'isExpired': cache.isExpired,
      };
    }
    
    return stats;
  }

  /// Cleanup expired caches
  void cleanupExpiredCaches() {
    final expiredKeys = <String>[];
    
    for (final entry in _caches.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _caches.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      developer.log('Cleaned up ${expiredKeys.length} expired caches', name: 'LazyLoadingService');
    }
  }
}

/// Lazy data loader for a specific data type
class LazyDataLoader<T> {
  final String cacheKey;
  final Future<List<T>> Function(int offset, int limit) dataFetcher;
  final String Function(T item) itemIdExtractor;
  final int pageSize;
  final LazyLoadingService lazyLoadingService;

  LazyDataCache get _cache => lazyLoadingService._getCache(cacheKey);
  PerformanceMonitor get _performanceMonitor => lazyLoadingService._performanceMonitor;

  LazyDataLoader({
    required this.cacheKey,
    required this.dataFetcher,
    required this.itemIdExtractor,
    required this.pageSize,
    required this.lazyLoadingService,
  });

  /// Load items for a specific page
  Future<List<T>> loadPage(int pageIndex) async {
    return await _performanceMonitor.trackQuery('lazy_load_page_$cacheKey', () async {
      final offset = pageIndex * pageSize;
      
      // Check cache first
      if (_cache.hasPage(pageIndex)) {
        _cache.cacheHits++;
        _cache.lastAccessed = DateTime.now();
        return _cache.getPage<T>(pageIndex);
      }
      
      // Load from data source
      _cache.cacheMisses++;
      final items = await dataFetcher(offset, pageSize);
      
      // Cache the results
      _cache.setPage(pageIndex, items);
      _cache.lastAccessed = DateTime.now();
      
      developer.log('Loaded page $pageIndex for $cacheKey: ${items.length} items', 
                   name: 'LazyDataLoader');
      
      return items;
    });
  }

  /// Load items around a specific index (for smooth scrolling)
  Future<List<T>> loadItemsAround(int centerIndex, {int bufferSize = 10}) async {
    final startIndex = (centerIndex - bufferSize).clamp(0, double.infinity).toInt();
    final endIndex = centerIndex + bufferSize;
    
    final startPage = startIndex ~/ pageSize;
    final endPage = endIndex ~/ pageSize;
    
    final List<T> allItems = [];
    
    for (int page = startPage; page <= endPage; page++) {
      final pageItems = await loadPage(page);
      allItems.addAll(pageItems);
    }
    
    // Return only the requested range
    final actualStartIndex = startIndex % (allItems.length);
    final actualEndIndex = (endIndex + 1).clamp(0, allItems.length);
    
    if (actualStartIndex < allItems.length && actualEndIndex > actualStartIndex) {
      return allItems.sublist(actualStartIndex, actualEndIndex);
    }
    
    return [];
  }

  /// Get item by ID (searches cache first)
  Future<T?> getItemById(String itemId) async {
    return await _performanceMonitor.trackQuery('lazy_get_by_id_$cacheKey', () async {
      // Search in cache first
      for (final pageData in _cache.loadedPages.values) {
        for (final item in pageData) {
          if (itemIdExtractor(item as T) == itemId) {
            _cache.cacheHits++;
            return item;
          }
        }
      }
      
      // If not found in cache, we'd need to implement a search mechanism
      // For now, return null and let the caller handle it
      _cache.cacheMisses++;
      return null;
    });
  }

  /// Preload pages for better user experience
  Future<void> preloadPages(List<int> pageIndices) async {
    final futures = pageIndices.map((pageIndex) => loadPage(pageIndex));
    await Future.wait(futures);
    
    developer.log('Preloaded ${pageIndices.length} pages for $cacheKey', 
                 name: 'LazyDataLoader');
  }

  /// Invalidate cache (force reload on next access)
  void invalidateCache() {
    lazyLoadingService.clearCache(cacheKey);
    developer.log('Invalidated cache for $cacheKey', name: 'LazyDataLoader');
  }

  /// Get total number of items (if known)
  int? get totalItems => _cache.totalItems;

  /// Set total number of items (for pagination UI)
  set totalItems(int? count) => _cache.totalItems = count;

  /// Check if a specific page is loaded
  bool isPageLoaded(int pageIndex) => _cache.hasPage(pageIndex);

  /// Get cache statistics for this loader
  Map<String, dynamic> getStatistics() {
    return {
      'cacheKey': cacheKey,
      'pageSize': pageSize,
      'totalItems': _cache.totalItems,
      'loadedPages': _cache.loadedPages.length,
      'cacheHits': _cache.cacheHits,
      'cacheMisses': _cache.cacheMisses,
      'hitRate': _cache.cacheMisses > 0 
          ? (_cache.cacheHits / (_cache.cacheHits + _cache.cacheMisses)) * 100 
          : 0,
      'lastAccessed': _cache.lastAccessed?.toIso8601String(),
    };
  }
}

/// Cache for lazy-loaded data
class LazyDataCache {
  final String key;
  final Map<int, List<dynamic>> loadedPages = {};
  final DateTime createdAt = DateTime.now();
  
  DateTime? lastAccessed;
  int? totalItems;
  int cacheHits = 0;
  int cacheMisses = 0;

  LazyDataCache(this.key);

  /// Check if cache has expired
  bool get isExpired {
    return DateTime.now().difference(lastAccessed ?? createdAt) > LazyLoadingService._cacheExpiry;
  }

  /// Check if a page is loaded
  bool hasPage(int pageIndex) {
    return loadedPages.containsKey(pageIndex);
  }

  /// Get a specific page
  List<T> getPage<T>(int pageIndex) {
    return loadedPages[pageIndex]?.cast<T>() ?? [];
  }

  /// Set data for a specific page
  void setPage(int pageIndex, List<dynamic> items) {
    loadedPages[pageIndex] = items;
    
    // Limit cache size to prevent memory issues
    if (loadedPages.length > LazyLoadingService._maxCacheSize) {
      // Remove oldest pages (simple LRU)
      final sortedKeys = loadedPages.keys.toList()..sort();
      final keysToRemove = sortedKeys.take(loadedPages.length - LazyLoadingService._maxCacheSize);
      
      for (final key in keysToRemove) {
        loadedPages.remove(key);
      }
    }
  }

  /// Clear all cached pages
  void clear() {
    loadedPages.clear();
    cacheHits = 0;
    cacheMisses = 0;
    totalItems = null;
  }
}

/// Specialized lazy loaders for common database operations
class DatabaseLazyLoaders {
  final DatabaseService _databaseService;
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();

  DatabaseLazyLoaders(this._databaseService);

  /// Create lazy loader for food items
  LazyDataLoader<Map<String, dynamic>> createFoodItemsLoader(
    String adminUid, {
    String? department,
    int pageSize = 20,
  }) {
    final cacheKey = 'food_items_${adminUid}_${department ?? 'all'}';
    
    return _lazyLoadingService.createLoader<Map<String, dynamic>>(
      cacheKey: cacheKey,
      pageSize: pageSize,
      itemIdExtractor: (item) => item['id'] as String,
      dataFetcher: (offset, limit) async {
        // This would need to be implemented in the database service
        // For now, we'll fetch all and slice (not optimal, but works)
        final allItems = await _databaseService.getFoodItems(adminUid, department: department);
        final endIndex = (offset + limit).clamp(0, allItems.length);
        return allItems.sublist(offset.clamp(0, allItems.length), endIndex);
      },
    );
  }

  /// Create lazy loader for departments
  LazyDataLoader<Map<String, dynamic>> createDepartmentsLoader(
    String adminUid, {
    int pageSize = 20,
  }) {
    final cacheKey = 'departments_$adminUid';
    
    return _lazyLoadingService.createLoader<Map<String, dynamic>>(
      cacheKey: cacheKey,
      pageSize: pageSize,
      itemIdExtractor: (item) => item['id'] as String,
      dataFetcher: (offset, limit) async {
        final allItems = await _databaseService.getDepartments(adminUid);
        final endIndex = (offset + limit).clamp(0, allItems.length);
        return allItems.sublist(offset.clamp(0, allItems.length), endIndex);
      },
    );
  }

  /// Create lazy loader for bills
  LazyDataLoader<Map<String, dynamic>> createBillsLoader(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
    int pageSize = 20,
  }) {
    final cacheKey = 'bills_${adminUid}_${startDate?.millisecondsSinceEpoch}_${endDate?.millisecondsSinceEpoch}';
    
    return _lazyLoadingService.createLoader<Map<String, dynamic>>(
      cacheKey: cacheKey,
      pageSize: pageSize,
      itemIdExtractor: (item) => item['id'] as String,
      dataFetcher: (offset, limit) async {
        final allItems = await _databaseService.getBills(adminUid, startDate: startDate, endDate: endDate);
        final endIndex = (offset + limit).clamp(0, allItems.length);
        return allItems.sublist(offset.clamp(0, allItems.length), endIndex);
      },
    );
  }

  /// Clear all database-related caches
  void clearAllCaches() {
    _lazyLoadingService.clearAllCaches();
  }

  /// Get statistics for all database loaders
  Map<String, dynamic> getStatistics() {
    return _lazyLoadingService.getCacheStatistics();
  }
}
