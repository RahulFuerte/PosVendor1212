// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Project imports:
import '../../core/error/comprehensive_error_handler.dart';
import '../../core/network/connection_monitor.dart';
import 'enhanced_offline_manager.dart';
import 'image_cache_service.dart';
import 'local/sqlite_dao.dart';

/// Manages complete offline data availability ensuring all data is accessible offline
class CompleteOfflineDataManager {
  static final CompleteOfflineDataManager _instance = CompleteOfflineDataManager._internal();
  factory CompleteOfflineDataManager() => _instance;
  CompleteOfflineDataManager._internal();

  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  final SQLiteDAO _sqliteDAO = SQLiteDAO();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final EnhancedOfflineManager _offlineManager = EnhancedOfflineManager();
  final ComprehensiveErrorHandler _errorHandler = ComprehensiveErrorHandler();
  
  bool _isInitialized = false;
  final Map<String, List<Map<String, dynamic>>> _dataCache = {};
  final Set<String> _preloadingImages = {};

  /// Initialize the complete offline data manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _errorHandler.initialize();
      await _connectionMonitor.initialize();
      await _sqliteDAO.initialize();
      await _imageCacheService.initialize();
      await _offlineManager.initialize();

      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Ensure all food items are available offline with images
  Future<List<Map<String, dynamic>>> ensureFoodItemsOfflineAvailability(String adminUid, {String? department}) async {
    try {
      await _ensureInitialized();

      // Get food items from local database
      final List<Map<String, dynamic>> foodItems = await _sqliteDAO.getFoodItems(adminUid, department: department);
      

      // Ensure ALL food items have complete data available offline
      final List<Map<String, dynamic>> completeItems = [];
      for (final item in foodItems) {
        // Ensure all required fields are present with fallback values
        final completeItem = {
          'id': item['id'] ?? item['name'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
          'name': item['name'] ?? 'Unknown Item',
          'price': item['price'] ?? 0,
          'department': item['department'] ?? department ?? 'General',
          'description': item['description'] ?? '',
          'food_code': item['food_code'] ?? item['foodCode'] ?? '',
          'image_path': item['image_path'] ?? item['imagePath'] ?? item['image_url'] ?? item['imageUrl'] ?? '',
          'is_hot': item['is_hot'] ?? item['isHot'] ?? false,
          'stocks': item['stocks'] ?? 0,
          'created_at': item['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'updated_at': item['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'sync_status': item['sync_status'] ?? 'synced',
          'admin_uid': item['admin_uid'] ?? adminUid,
        };
        completeItems.add(completeItem);
      }

      // Ensure images are cached for offline access
      if (completeItems.isNotEmpty) {
        await _ensureImagesAreCached('food_items', completeItems);
      }

      // Cache the data for quick access
      final cacheKey = 'food_items_${adminUid}_${department ?? 'all'}';
      _dataCache[cacheKey] = completeItems;

      return completeItems;
    } catch (e) {
      await _errorHandler.handleRecoverableError(
        component: 'CompleteOfflineDataManager',
        message: 'Failed to ensure food items offline availability: $e',
        userMessage: 'Unable to load food items. Please check your device storage.',
      );
      
      // Return cached data if available
      final cacheKey = 'food_items_${adminUid}_${department ?? 'all'}';
      return _dataCache[cacheKey] ?? [];
    }
  }

  /// Ensure all departments are available offline with images
  Future<List<Map<String, dynamic>>> ensureDepartmentsOfflineAvailability(String adminUid) async {
    try {
      await _ensureInitialized();

      // Get departments from local database
      final List<Map<String, dynamic>> departments = await _sqliteDAO.getDepartments(adminUid);
      

      // Ensure ALL departments have complete data available offline
      final List<Map<String, dynamic>> completeDepartments = [];
      for (final dept in departments) {
        // Ensure all required fields are present with fallback values
        final completeDept = {
          'id': dept['id'] ?? dept['name'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
          'name': dept['name'] ?? 'Unknown Department',
          'status': dept['status'] ?? 'Active',
          'description': dept['description'] ?? '',
          'image_url': dept['image_url'] ?? dept['imageUrl'] ?? dept['image_path'] ?? dept['imagePath'] ?? '',
          'created_at': dept['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'updated_at': dept['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'sync_status': dept['sync_status'] ?? 'synced',
          'admin_uid': dept['admin_uid'] ?? adminUid,
        };
        completeDepartments.add(completeDept);
      }

      // Ensure images are cached for offline access
      if (completeDepartments.isNotEmpty) {
        await _ensureImagesAreCached('departments', completeDepartments);
      }

      // Cache the data for quick access
      final cacheKey = 'departments_$adminUid';
      _dataCache[cacheKey] = completeDepartments;

      return completeDepartments;
    } catch (e) {
      await _errorHandler.handleRecoverableError(
        component: 'CompleteOfflineDataManager',
        message: 'Failed to ensure departments offline availability: $e',
        userMessage: 'Unable to load departments. Please check your device storage.',
      );
      
      // Return cached data if available
      final cacheKey = 'departments_$adminUid';
      return _dataCache[cacheKey] ?? [];
    }
  }

  /// Ensure all bills are available offline
  Future<List<Map<String, dynamic>>> ensureBillsOfflineAvailability(String adminUid, {DateTime? startDate, DateTime? endDate, bool forceRefresh = false}) async {
    try {
      await _ensureInitialized();

      // Clear cache if force refresh
      final cacheKey = 'bills_${adminUid}_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';
      if (forceRefresh) {
        _dataCache.remove(cacheKey);
        // Also clear SQLiteDAO cache to get fresh data
        _sqliteDAO.clearCacheForQueryType('getBills');
      }

      // Get bills from local database (fresh data after cache clear)
      final List<Map<String, dynamic>> bills = await _sqliteDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
      

      // Ensure ALL bills have complete data available offline
      final List<Map<String, dynamic>> completeBills = [];
      for (final bill in bills) {
        // Ensure all required fields are present with fallback values
        // Keep sync_status as-is (int) to preserve the actual status
        final completeBill = {
          'id': bill['id'] ?? 'bill_${DateTime.now().millisecondsSinceEpoch}',
          'bill_number': bill['bill_number'] ?? bill['billNumber'] ?? 'N/A',
          'customer_name': bill['customer_name'] ?? bill['customerName'] ?? 'Walk-in Customer',
          'customer_phone': bill['customer_phone'] ?? bill['customerPhone'] ?? '',
          'total_amount': bill['total_amount'] ?? bill['totalAmount'] ?? 0,
          'tax_amount': bill['tax_amount'] ?? bill['taxAmount'] ?? 0,
          'discount_amount': bill['discount_amount'] ?? bill['discountAmount'] ?? 0,
          'bill_date': bill['bill_date'] ?? bill['billDate'] ?? DateTime.now().millisecondsSinceEpoch,
          'items': bill['items'] ?? '[]', // JSON string of items
          'payment_method': bill['payment_method'] ?? bill['paymentMethod'] ?? 'Cash',
          'status': bill['status'] ?? 'Completed',
          'created_at': bill['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'updated_at': bill['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'sync_status': bill['sync_status'] ?? 0, // Keep as int: 0=synced, 1=pending, 2=conflict
          'admin_uid': bill['admin_uid'] ?? adminUid,
        };
        completeBills.add(completeBill);
      }

      // Cache the data for quick access
      _dataCache[cacheKey] = completeBills;

      return completeBills;
    } catch (e) {
      await _errorHandler.handleRecoverableError(
        component: 'CompleteOfflineDataManager',
        message: 'Failed to ensure bills offline availability: $e',
        userMessage: 'Unable to load bills. Please check your device storage.',
      );
      
      // Return cached data if available
      final cacheKey = 'bills_${adminUid}_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';
      return _dataCache[cacheKey] ?? [];
    }
  }

  /// Ensure images are cached for offline display
  Future<void> _ensureImagesAreCached(String tableName, List<Map<String, dynamic>> records) async {
    try {
      final List<String> imageUrls = [];
      final List<String> recordIds = [];

      // Collect image URLs and record IDs
      for (final record in records) {
        final recordId = record['id']?.toString();
        final imageUrl = record['image_path']?.toString() ?? 
                        record['image_url']?.toString() ?? 
                        record['imagePath']?.toString() ?? 
                        record['imageUrl']?.toString();

        if (recordId != null && imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'N/A') {
          // Check if image is already cached
          final isCached = await _imageCacheService.isImageCached(tableName, recordId);
          if (!isCached && !_preloadingImages.contains('${tableName}_$recordId')) {
            imageUrls.add(imageUrl);
            recordIds.add(recordId);
            _preloadingImages.add('${tableName}_$recordId');
          }
        }
      }

      if (imageUrls.isNotEmpty) {
        
        // Download and cache images with controlled concurrency
        await _imageCacheService.downloadAndCacheMultipleImages(
          imageUrls,
          tableName: tableName,
          recordIds: recordIds,
          maxConcurrency: 2, // Limit concurrent downloads to avoid overwhelming the system
        );

        // Remove from preloading set
        for (int i = 0; i < recordIds.length; i++) {
          _preloadingImages.remove('${tableName}_${recordIds[i]}');
        }

      }
    } catch (e) {
      // Don't throw error for image caching failures - data should still be available
    }
  }

  /// Get cached image for offline display with enhanced fallback
  Future<Uint8List?> getCachedImageForOfflineDisplay(String tableName, String recordId) async {
    try {
      // First try to get from image cache
      final cachedImage = await _imageCacheService.getImageBlob(tableName, recordId);
      if (cachedImage != null) {
        return cachedImage;
      }

      // If not in cache, try to get from main table BLOB field
      final blobImage = await _sqliteDAO.getImageBlob(tableName, recordId);
      if (blobImage != null) {
        return blobImage;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Ensure offline image availability for a specific record
  Future<bool> ensureOfflineImageAvailability(String tableName, String recordId, String imageUrl) async {
    try {
      if (imageUrl.isEmpty || imageUrl == 'N/A') {
        return false;
      }

      // Check if image is already cached
      final isCached = await _imageCacheService.isImageCached(tableName, recordId);
      if (isCached) {
        return true;
      }

      // Check if we're online to download the image
      final isOnline = !_connectionMonitor.isConnected;
      if (isOnline) {
        return false;
      }

      // Download and cache the image
      final imageData = await _imageCacheService.downloadAndCacheImage(
        imageUrl,
        tableName: tableName,
        recordId: recordId,
      );

      if (imageData != null) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Preload all critical data for offline use
  Future<void> preloadAllCriticalData(String adminUid) async {
    try {
      await _ensureInitialized();


      // Preload departments first (needed for navigation)
      final departments = await ensureDepartmentsOfflineAvailability(adminUid);
      
      // Preload all food items
      final allFoodItems = await ensureFoodItemsOfflineAvailability(adminUid);
      
      // Preload recent bills (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentBills = await ensureBillsOfflineAvailability(adminUid, startDate: thirtyDaysAgo);



      await _errorHandler.handleInfo(
        component: 'CompleteOfflineDataManager',
        message: 'Successfully preloaded all critical data for offline use',
      );
    } catch (e) {
      await _errorHandler.handleWarning(
        component: 'CompleteOfflineDataManager',
        message: 'Failed to preload some critical data: $e',
        userMessage: 'Some data may not be available offline. Please ensure you have sufficient storage space.',
      );
    }
  }

  /// Ensure complete offline data availability for all data types
  Future<Map<String, dynamic>> ensureCompleteOfflineDataAvailability(String adminUid) async {
    try {
      await _ensureInitialized();


      final Map<String, dynamic> result = {
        'success': true,
        'data': {},
        'availability': {},
        'errors': [],
      };

      // 1. Ensure all departments are available offline
      try {
        final departments = await ensureDepartmentsOfflineAvailability(adminUid);
        result['data']['departments'] = departments;
        result['availability']['departments'] = departments.isNotEmpty;
      } catch (e) {
        result['errors'].add('Failed to ensure departments availability: $e');
        result['availability']['departments'] = false;
      }

      // 2. Ensure all food items are available offline
      try {
        final foodItems = await ensureFoodItemsOfflineAvailability(adminUid);
        result['data']['food_items'] = foodItems;
        result['availability']['food_items'] = foodItems.isNotEmpty;
      } catch (e) {
        result['errors'].add('Failed to ensure food items availability: $e');
        result['availability']['food_items'] = false;
      }

      // 3. Ensure all bills are available offline
      try {
        final bills = await ensureBillsOfflineAvailability(adminUid);
        result['data']['bills'] = bills;
        result['availability']['bills'] = bills.isNotEmpty;
      } catch (e) {
        result['errors'].add('Failed to ensure bills availability: $e');
        result['availability']['bills'] = false;
      }

      // 4. Check image cache availability
      try {
        final cacheStats = await _imageCacheService.getCacheStatistics();
        result['availability']['images'] = (cacheStats['totalImages'] as int? ?? 0) > 0;
        result['data']['image_stats'] = cacheStats;
      } catch (e) {
        result['errors'].add('Failed to check image cache: $e');
        result['availability']['images'] = false;
      }

      // 5. Validate data completeness
      final completenessCheck = await _validateDataCompleteness(result['data']);
      result['completeness'] = completenessCheck;

      // 6. Set overall success status
      result['success'] = (result['errors'] as List).isEmpty;

      
      return result;
    } catch (e) {
      return {
        'success': false,
        'data': {},
        'availability': {
          'departments': false,
          'food_items': false,
          'bills': false,
          'images': false,
        },
        'errors': ['Critical error: $e'],
      };
    }
  }

  /// Validate data completeness for offline availability
  Future<Map<String, dynamic>> _validateDataCompleteness(Map<String, dynamic> data) async {
    final Map<String, dynamic> completeness = {
      'overall_score': 0.0,
      'details': {},
    };

    int totalChecks = 0;
    int passedChecks = 0;

    // Check departments completeness
    final departments = data['departments'] as List<Map<String, dynamic>>? ?? [];
    int deptComplete = 0;
    for (final dept in departments) {
      totalChecks++;
      if (dept['name'] != null && dept['name'].toString().isNotEmpty) {
        deptComplete++;
        passedChecks++;
      }
    }
    completeness['details']['departments'] = {
      'total': departments.length,
      'complete': deptComplete,
      'percentage': departments.isEmpty ? 0.0 : (deptComplete / departments.length) * 100,
    };

    // Check food items completeness
    final foodItems = data['food_items'] as List<Map<String, dynamic>>? ?? [];
    int itemsComplete = 0;
    for (final item in foodItems) {
      totalChecks++;
      if (item['name'] != null && 
          item['name'].toString().isNotEmpty && 
          item['price'] != null) {
        itemsComplete++;
        passedChecks++;
      }
    }
    completeness['details']['food_items'] = {
      'total': foodItems.length,
      'complete': itemsComplete,
      'percentage': foodItems.isEmpty ? 0.0 : (itemsComplete / foodItems.length) * 100,
    };

    // Check bills completeness
    final bills = data['bills'] as List<Map<String, dynamic>>? ?? [];
    int billsComplete = 0;
    for (final bill in bills) {
      totalChecks++;
      if (bill['id'] != null && 
          bill['total_amount'] != null && 
          bill['bill_date'] != null) {
        billsComplete++;
        passedChecks++;
      }
    }
    completeness['details']['bills'] = {
      'total': bills.length,
      'complete': billsComplete,
      'percentage': bills.isEmpty ? 0.0 : (billsComplete / bills.length) * 100,
    };

    // Calculate overall completeness score
    completeness['overall_score'] = totalChecks == 0 ? 0.0 : (passedChecks / totalChecks) * 100;

    return completeness;
  }

  /// Check if all critical data is available offline
  Future<Map<String, bool>> checkOfflineDataAvailability(String adminUid) async {
    try {
      await _ensureInitialized();

      final Map<String, bool> availability = {};

      // Check food items availability
      final foodItems = await _sqliteDAO.getFoodItems(adminUid);
      availability['food_items'] = foodItems.isNotEmpty;

      // Check departments availability
      final departments = await _sqliteDAO.getDepartments(adminUid);
      availability['departments'] = departments.isNotEmpty;

      // Check bills availability
      final bills = await _sqliteDAO.getBills(adminUid);
      availability['bills'] = bills.isNotEmpty;

      // Check image cache statistics
      final cacheStats = await _imageCacheService.getCacheStatistics();
      availability['images'] = (cacheStats['totalImages'] as int? ?? 0) > 0;

      return availability;
    } catch (e) {
      return {
        'food_items': false,
        'departments': false,
        'bills': false,
        'images': false,
      };
    }
  }

  /// Get comprehensive offline data statistics
  Future<Map<String, dynamic>> getOfflineDataStatistics(String adminUid) async {
    try {
      await _ensureInitialized();

      final foodItemsCount = await _sqliteDAO.getFoodItemsCount(adminUid);
      final departments = await _sqliteDAO.getDepartments(adminUid);
      final bills = await _sqliteDAO.getBills(adminUid);
      final pendingItemsCount = await _sqliteDAO.getPendingItemsCount();
      final cacheStats = await _imageCacheService.getCacheStatistics();
      final availability = await checkOfflineDataAvailability(adminUid);

      return {
        'food_items_count': foodItemsCount,
        'departments_count': departments.length,
        'bills_count': bills.length,
        'pending_sync_count': pendingItemsCount,
        'cached_images_count': cacheStats['totalImages'] ?? 0,
        'cache_size_bytes': cacheStats['totalSizeBytes'] ?? 0,
        'is_offline': !_connectionMonitor.isConnected,
        'data_availability': availability,
        'last_sync_time': _offlineManager.currentStatus.lastSyncTime?.toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'is_offline': !_connectionMonitor.isConnected,
      };
    }
  }

  /// Clear cached data to free up memory
  void clearDataCache() {
    _dataCache.clear();
  }

  /// Ensure the manager is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Dispose resources
  void dispose() {
    _dataCache.clear();
    _preloadingImages.clear();
    _isInitialized = false;
  }
}
