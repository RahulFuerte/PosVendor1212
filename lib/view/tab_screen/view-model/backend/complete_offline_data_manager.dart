import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'connection_monitor.dart';
import 'sqlite_dao.dart';
import 'image_cache_service.dart';
import 'enhanced_offline_manager.dart';
import 'comprehensive_error_handler.dart';

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
      developer.log('CompleteOfflineDataManager initialized successfully', name: 'OfflineDataManager');
    } catch (e) {
      developer.log('Error initializing CompleteOfflineDataManager: $e', name: 'OfflineDataManager');
      rethrow;
    }
  }

  /// Ensure all food items are available offline with images
  Future<List<Map<String, dynamic>>> ensureFoodItemsOfflineAvailability(String adminUid, {String? department}) async {
    try {
      await _ensureInitialized();

      // Get food items from local database
      final List<Map<String, dynamic>> foodItems = await _sqliteDAO.getFoodItems(adminUid, department: department);
      
      developer.log('Retrieved ${foodItems.length} food items from local database', name: 'OfflineDataManager');

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

      developer.log('Ensured complete offline availability for ${completeItems.length} food items', name: 'OfflineDataManager');
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
      
      developer.log('Retrieved ${departments.length} departments from local database', name: 'OfflineDataManager');

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

      developer.log('Ensured complete offline availability for ${completeDepartments.length} departments', name: 'OfflineDataManager');
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
  Future<List<Map<String, dynamic>>> ensureBillsOfflineAvailability(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    try {
      await _ensureInitialized();

      // Get bills from local database
      final List<Map<String, dynamic>> bills = await _sqliteDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
      
      developer.log('Retrieved ${bills.length} bills from local database', name: 'OfflineDataManager');

      // Ensure ALL bills have complete data available offline
      final List<Map<String, dynamic>> completeBills = [];
      for (final bill in bills) {
        // Ensure all required fields are present with fallback values
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
          'sync_status': bill['sync_status'] ?? 'synced',
          'admin_uid': bill['admin_uid'] ?? adminUid,
        };
        completeBills.add(completeBill);
      }

      // Cache the data for quick access
      final cacheKey = 'bills_${adminUid}_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';
      _dataCache[cacheKey] = completeBills;

      developer.log('Ensured complete offline availability for ${completeBills.length} bills', name: 'OfflineDataManager');
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
        developer.log('Preloading ${imageUrls.length} images for $tableName', name: 'OfflineDataManager');
        
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

        developer.log('Completed preloading images for $tableName', name: 'OfflineDataManager');
      }
    } catch (e) {
      developer.log('Error ensuring images are cached: $e', name: 'OfflineDataManager');
      // Don't throw error for image caching failures - data should still be available
    }
  }

  /// Get cached image for offline display with enhanced fallback
  Future<Uint8List?> getCachedImageForOfflineDisplay(String tableName, String recordId) async {
    try {
      // First try to get from image cache
      final cachedImage = await _imageCacheService.getImageBlob(tableName, recordId);
      if (cachedImage != null) {
        developer.log('Image retrieved from cache for $tableName:$recordId', name: 'OfflineDataManager');
        return cachedImage;
      }

      // If not in cache, try to get from main table BLOB field
      final blobImage = await _sqliteDAO.getImageBlob(tableName, recordId);
      if (blobImage != null) {
        developer.log('Image retrieved from main table BLOB for $tableName:$recordId', name: 'OfflineDataManager');
        return blobImage;
      }

      developer.log('No cached image found for $tableName:$recordId', name: 'OfflineDataManager');
      return null;
    } catch (e) {
      developer.log('Error getting cached image: $e', name: 'OfflineDataManager');
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
        developer.log('Image already cached for $tableName:$recordId', name: 'OfflineDataManager');
        return true;
      }

      // Check if we're online to download the image
      final isOnline = !_connectionMonitor.isConnected;
      if (isOnline) {
        developer.log('Offline mode - cannot download image for $tableName:$recordId', name: 'OfflineDataManager');
        return false;
      }

      // Download and cache the image
      final imageData = await _imageCacheService.downloadAndCacheImage(
        imageUrl,
        tableName: tableName,
        recordId: recordId,
      );

      if (imageData != null) {
        developer.log('Successfully downloaded and cached image for $tableName:$recordId', name: 'OfflineDataManager');
        return true;
      }

      return false;
    } catch (e) {
      developer.log('Error ensuring offline image availability: $e', name: 'OfflineDataManager');
      return false;
    }
  }

  /// Preload all critical data for offline use
  Future<void> preloadAllCriticalData(String adminUid) async {
    try {
      await _ensureInitialized();

      developer.log('Starting preload of all critical data for offline use', name: 'OfflineDataManager');

      // Preload departments first (needed for navigation)
      final departments = await ensureDepartmentsOfflineAvailability(adminUid);
      
      // Preload all food items
      final allFoodItems = await ensureFoodItemsOfflineAvailability(adminUid);
      
      // Preload recent bills (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentBills = await ensureBillsOfflineAvailability(adminUid, startDate: thirtyDaysAgo);

      developer.log('Preloaded critical data: ${departments.length} departments, ${allFoodItems.length} food items, ${recentBills.length} recent bills', 
                   name: 'OfflineDataManager');

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

      developer.log('Starting complete offline data availability check for admin: $adminUid', name: 'OfflineDataManager');

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
        developer.log('✓ Departments offline availability ensured: ${departments.length} items', name: 'OfflineDataManager');
      } catch (e) {
        result['errors'].add('Failed to ensure departments availability: $e');
        result['availability']['departments'] = false;
      }

      // 2. Ensure all food items are available offline
      try {
        final foodItems = await ensureFoodItemsOfflineAvailability(adminUid);
        result['data']['food_items'] = foodItems;
        result['availability']['food_items'] = foodItems.isNotEmpty;
        developer.log('✓ Food items offline availability ensured: ${foodItems.length} items', name: 'OfflineDataManager');
      } catch (e) {
        result['errors'].add('Failed to ensure food items availability: $e');
        result['availability']['food_items'] = false;
      }

      // 3. Ensure all bills are available offline
      try {
        final bills = await ensureBillsOfflineAvailability(adminUid);
        result['data']['bills'] = bills;
        result['availability']['bills'] = bills.isNotEmpty;
        developer.log('✓ Bills offline availability ensured: ${bills.length} items', name: 'OfflineDataManager');
      } catch (e) {
        result['errors'].add('Failed to ensure bills availability: $e');
        result['availability']['bills'] = false;
      }

      // 4. Check image cache availability
      try {
        final cacheStats = await _imageCacheService.getCacheStatistics();
        result['availability']['images'] = (cacheStats['totalImages'] as int? ?? 0) > 0;
        result['data']['image_stats'] = cacheStats;
        developer.log('✓ Image cache availability checked: ${cacheStats['totalImages']} cached images', name: 'OfflineDataManager');
      } catch (e) {
        result['errors'].add('Failed to check image cache: $e');
        result['availability']['images'] = false;
      }

      // 5. Validate data completeness
      final completenessCheck = await _validateDataCompleteness(result['data']);
      result['completeness'] = completenessCheck;

      // 6. Set overall success status
      result['success'] = (result['errors'] as List).isEmpty;

      developer.log('Complete offline data availability check completed. Success: ${result['success']}', name: 'OfflineDataManager');
      
      return result;
    } catch (e) {
      developer.log('Error ensuring complete offline data availability: $e', name: 'OfflineDataManager');
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
      developer.log('Error checking offline data availability: $e', name: 'OfflineDataManager');
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
      developer.log('Error getting offline data statistics: $e', name: 'OfflineDataManager');
      return {
        'error': e.toString(),
        'is_offline': !_connectionMonitor.isConnected,
      };
    }
  }

  /// Clear cached data to free up memory
  void clearDataCache() {
    _dataCache.clear();
    developer.log('Cleared data cache', name: 'OfflineDataManager');
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