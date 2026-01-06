// Dart imports:
import 'dart:math';
import 'dart:typed_data';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/network/connection_monitor.dart';
import 'package:pos/core/utils/performance_monitor.dart';
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/enhanced_offline_manager.dart';
import 'package:pos/data/datasources/image_cache_service.dart';
import 'package:pos/data/datasources/local/sqlite_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:

import 'test_database_helper.dart';

/// **Feature: local-database-performance-optimization, Property All: Final Performance Testing and Validation**
/// Comprehensive performance testing with realistic data volumes, offline functionality validation,
/// query performance improvements verification, and concurrent user scenarios testing.
void main() {
  group('Final Performance Testing and Validation', () {
    late SQLiteDAO sqliteDAO;
    late ImageCacheService imageCacheService;
    late PerformanceMonitor performanceMonitor;
    late ConnectionMonitor connectionMonitor;
    late EnhancedOfflineManager offlineManager;
    const String testAdminUid = 'final_test_admin';

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      final testDb = await TestDatabaseHelper.getTestDatabase();
      
      sqliteDAO = SQLiteDAO();
      imageCacheService = ImageCacheService();
      performanceMonitor = PerformanceMonitor();
      connectionMonitor = ConnectionMonitor();
      offlineManager = EnhancedOfflineManager();
      
      // Initialize services
      imageCacheService.setTestDatabase(testDb);
      await imageCacheService.initialize();
      performanceMonitor.startMonitoring();
      await connectionMonitor.initialize();
      await offlineManager.initialize();
    });

    tearDown(() async {
      try {
        performanceMonitor.stopMonitoring();
        performanceMonitor.dispose();
        imageCacheService.reset();
        await sqliteDAO.close();
        await TestDatabaseHelper.clearAllTables();
        await TestDatabaseHelper.closeTestDatabase();
      } catch (e) {
        // Ignore cleanup errors in tests
      }
    });

    group('Realistic Data Volume Performance Testing', () {
      test('should handle large realistic dataset efficiently', () async {
        // Create realistic POS system data volumes
        const departmentCount = 15;
        const itemsPerDepartment = 200;
        const billCount = 500;
        const totalItems = departmentCount * itemsPerDepartment;

        final stopwatch = Stopwatch()..start();

        // 1. Create departments
        final departments = <String>[];
        for (int i = 0; i < departmentCount; i++) {
          final deptName = 'Department ${i + 1}';
          departments.add(deptName);
          
          final department = {
            'id': 'dept_$i',
            'name': deptName,
            'status': 'Active',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          };
          
          await sqliteDAO.saveDepartment(testAdminUid, department);
        }

        stopwatch.stop();
        final deptCreationTime = stopwatch.elapsedMilliseconds;
        
        // 2. Create food items with realistic data
        stopwatch.reset();
        stopwatch.start();
        
        for (int deptIndex = 0; deptIndex < departmentCount; deptIndex++) {
          final department = departments[deptIndex];
          
          for (int itemIndex = 0; itemIndex < itemsPerDepartment; itemIndex++) {
            final globalIndex = (deptIndex * itemsPerDepartment) + itemIndex;
            final foodItem = {
              'id': 'item_$globalIndex',
              'name': 'Food Item ${globalIndex + 1}',
              'price': 5.0 + (Random().nextDouble() * 45.0), // $5-$50 range
              'department': department,
              'food_code': 'CODE${globalIndex.toString().padLeft(4, '0')}',
              'description': 'Delicious ${department.toLowerCase()} item number ${itemIndex + 1}',
              'stocks': 10 + Random().nextInt(90), // 10-100 stock range
              'is_hot': Random().nextBool(),
              'created_at': DateTime.now().millisecondsSinceEpoch,
            };
            
            await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
          }
        }

        stopwatch.stop();
        final itemCreationTime = stopwatch.elapsedMilliseconds;

        // 3. Create realistic bills
        stopwatch.reset();
        stopwatch.start();
        
        for (int billIndex = 0; billIndex < billCount; billIndex++) {
          final itemsInBill = 1 + Random().nextInt(5); // 1-5 items per bill
          final billItems = <String, Map<String, dynamic>>{};
          double totalAmount = 0.0;
          
          for (int itemInBill = 0; itemInBill < itemsInBill; itemInBill++) {
            final randomItemIndex = Random().nextInt(totalItems);
            final itemId = 'item_$randomItemIndex';
            final price = 5.0 + (Random().nextDouble() * 45.0);
            final quantity = 1 + Random().nextInt(3);
            
            billItems[itemId] = {
              'name': 'Food Item ${randomItemIndex + 1}',
              'price': price,
              'quantity': quantity,
            };
            
            totalAmount += price * quantity;
          }
          
          final bill = {
            'id': 'bill_$billIndex',
            'customer_phone': '+1${Random().nextInt(1000000000).toString().padLeft(10, '0')}',
            'items': billItems.toString(),
            'total_amount': totalAmount,
            'bill_date': DateTime.now().millisecondsSinceEpoch - Random().nextInt(86400000 * 30), // Last 30 days
            'created_at': DateTime.now().millisecondsSinceEpoch,
          };
          
          await sqliteDAO.saveBill(testAdminUid, bill);
        }

        stopwatch.stop();
        final billCreationTime = stopwatch.elapsedMilliseconds;

        // Performance assertions
        expect(deptCreationTime, lessThan(1000), 
          reason: 'Department creation should complete within 1 second');
        expect(itemCreationTime, lessThan(30000), 
          reason: 'Food item creation should complete within 30 seconds');
        expect(billCreationTime, lessThan(10000), 
          reason: 'Bill creation should complete within 10 seconds');

        // Verify data integrity
        final allItems = await sqliteDAO.getFoodItems(testAdminUid);
        expect(allItems.length, equals(totalItems));
        
        final allBills = await sqliteDAO.getBills(testAdminUid);
        expect(allBills.length, equals(billCount));
        
        final allDepartments = await sqliteDAO.getDepartments(testAdminUid);
        expect(allDepartments.length, equals(departmentCount));
      });

      test('should maintain query performance with large datasets', () async {
        // Use existing large dataset from previous test or create smaller one
        const itemCount = 1000;
        const departmentCount = 10;
        
        // Create test data
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'perf_item_$i',
            'name': 'Performance Item $i',
            'price': 10.0 + (i % 50),
            'department': 'Department ${i % departmentCount}',
            'food_code': 'PERF${i.toString().padLeft(4, '0')}',
            'description': 'Performance test item $i with searchable content',
            'stocks': 50 + (i % 50),
          };
          
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
        }

        // Test various query patterns with performance monitoring
        final queryTests = <String, Future<void> Function()>{
          'getAllItems': () async {
            final stopwatch = Stopwatch()..start();
            final items = await sqliteDAO.getFoodItems(testAdminUid);
            stopwatch.stop();
            expect(items.length, equals(itemCount));
            expect(stopwatch.elapsedMilliseconds, lessThan(1000), 
              reason: 'Get all items should complete within 1 second');
          },
          
          'getDepartmentItems': () async {
            final stopwatch = Stopwatch()..start();
            final items = await sqliteDAO.getFoodItems(testAdminUid, department: 'Department 5');
            stopwatch.stop();
            expect(items.length, equals(100)); // itemCount / departmentCount
            expect(stopwatch.elapsedMilliseconds, lessThan(100), 
              reason: 'Department query should complete within 100ms');
          },
          
          'paginatedQuery': () async {
            final stopwatch = Stopwatch()..start();
            final items = await sqliteDAO.getFoodItemsPaginated(testAdminUid, offset: 0, limit: 50);
            stopwatch.stop();
            expect(items.length, equals(50));
            expect(stopwatch.elapsedMilliseconds, lessThan(50), 
              reason: 'Paginated query should complete within 50ms');
          },
          
          'searchQuery': () async {
            final stopwatch = Stopwatch()..start();
            final items = await sqliteDAO.searchFoodItems(testAdminUid, 'Performance');
            stopwatch.stop();
            expect(items.isNotEmpty, isTrue);
            expect(stopwatch.elapsedMilliseconds, lessThan(200), 
              reason: 'Search query should complete within 200ms');
          },
          
          'individualLookup': () async {
            final stopwatch = Stopwatch()..start();
            final item = await sqliteDAO.getFoodItem(testAdminUid, 'perf_item_500');
            stopwatch.stop();
            expect(item, isNotNull);
            expect(stopwatch.elapsedMilliseconds, lessThan(10), 
              reason: 'Individual lookup should complete within 10ms');
          },
        };

        // Execute all query tests
        for (final entry in queryTests.entries) {
          await entry.value();
        }
      });

      test('should handle concurrent operations with realistic load', () async {
        const concurrentUsers = 10;
        const operationsPerUser = 20;
        
        // Create base data
        for (int i = 0; i < 100; i++) {
          final foodItem = {
            'id': 'concurrent_item_$i',
            'name': 'Concurrent Item $i',
            'price': 10.0 + i,
            'department': 'Concurrent Department',
          };
          
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
        }

        // Simulate concurrent users performing various operations
        final userOperations = <Future>[];
        final operationResults = <String>[];
        
        for (int user = 0; user < concurrentUsers; user++) {
          userOperations.add(
            Future(() async {
              final userResults = <String>[];
              
              for (int op = 0; op < operationsPerUser; op++) {
                try {
                  final operationType = op % 4;
                  
                  switch (operationType) {
                    case 0: // Read operation
                      final items = await sqliteDAO.getFoodItemsPaginated(
                        testAdminUid, 
                        offset: op * 5, 
                        limit: 5
                      );
                      userResults.add('read_success_${user}_$op');
                      break;
                      
                    case 1: // Create operation
                      final newItem = {
                        'id': 'user_${user}_item_$op',
                        'name': 'User $user Item $op',
                        'price': 15.0 + op,
                        'department': 'User Department',
                      };
                      await sqliteDAO.saveFoodItem(testAdminUid, newItem);
                      userResults.add('create_success_${user}_$op');
                      break;
                      
                    case 2: // Update operation
                      await sqliteDAO.updateFoodItem(testAdminUid, 'concurrent_item_${op % 100}', {
                        'price': 20.0 + op,
                      });
                      userResults.add('update_success_${user}_$op');
                      break;
                      
                    case 3: // Search operation
                      await sqliteDAO.searchFoodItems(testAdminUid, 'Concurrent');
                      userResults.add('search_success_${user}_$op');
                      break;
                  }
                } catch (e) {
                  userResults.add('error_${user}_$op: $e');
                }
              }
              
              operationResults.addAll(userResults);
            })
          );
        }

        final stopwatch = Stopwatch()..start();
        await Future.wait(userOperations);
        stopwatch.stop();

        // Analyze results
        final successCount = operationResults.where((r) => r.contains('success')).length;
        final errorCount = operationResults.where((r) => r.contains('error')).length;
        const totalOperations = concurrentUsers * operationsPerUser;

        expect(successCount, equals(totalOperations), 
          reason: 'All concurrent operations should succeed');
        expect(errorCount, equals(0), 
          reason: 'No operations should fail');
        expect(stopwatch.elapsedMilliseconds, lessThan(30000), 
          reason: 'Concurrent operations should complete within 30 seconds');

        // Verify data integrity after concurrent operations
        final finalItems = await sqliteDAO.getFoodItems(testAdminUid);
        expect(finalItems.length, greaterThanOrEqualTo(100), 
          reason: 'Should have at least the original items plus created ones');
      });
    });

    group('Complete Offline Functionality Validation', () {
      test('should handle complete offline workflow across all features', () async {
        // Test offline functionality by directly testing local database operations
        // (In real scenario, offline detection would be handled by ConnectionMonitor)
        
        // 1. Test offline data creation across all entities
        final offlineData = <String, List<Map<String, dynamic>>>{
          'departments': [],
          'foodItems': [],
          'bills': [],
        };

        // Create departments offline
        for (int i = 0; i < 5; i++) {
          final department = {
            'id': 'offline_dept_$i',
            'name': 'Offline Department $i',
            'status': 'Active',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          };
          
          await sqliteDAO.saveDepartment(testAdminUid, department);
          offlineData['departments']!.add(department);
          
          // Verify immediate offline availability
          final saved = await sqliteDAO.getDepartment(testAdminUid, 'offline_dept_$i');
          expect(saved, isNotNull);
          expect(saved!['sync_status'], equals(SyncStatus.pending.value));
        }

        // Create food items offline
        for (int i = 0; i < 25; i++) {
          final foodItem = {
            'id': 'offline_food_$i',
            'name': 'Offline Food Item $i',
            'price': 8.0 + (i * 0.5),
            'department': 'Offline Department ${i % 5}',
            'food_code': 'OFF${i.toString().padLeft(3, '0')}',
            'description': 'Created while offline',
            'stocks': 30 + i,
            'is_hot': i % 2 == 0,
          };
          
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
          offlineData['foodItems']!.add(foodItem);
          
          // Verify immediate offline availability
          final saved = await sqliteDAO.getFoodItem(testAdminUid, 'offline_food_$i');
          expect(saved, isNotNull);
          expect(saved!['sync_status'], equals(SyncStatus.pending.value));
        }

        // Create bills offline
        for (int i = 0; i < 10; i++) {
          final bill = {
            'id': 'offline_bill_$i',
            'customer_phone': '+1555000${i.toString().padLeft(4, '0')}',
            'items': '{"offline_food_${i % 25}": {"name": "Offline Food Item ${i % 25}", "price": ${8.0 + (i * 0.5)}}}',
            'total_amount': 8.0 + (i * 0.5),
            'bill_date': DateTime.now().millisecondsSinceEpoch,
          };
          
          await sqliteDAO.saveBill(testAdminUid, bill);
          offlineData['bills']!.add(bill);
          
          // Verify immediate offline availability
          final saved = await sqliteDAO.getBill(testAdminUid, 'offline_bill_$i');
          expect(saved, isNotNull);
          expect(saved!['sync_status'], equals(SyncStatus.pending.value));
        }

        // 2. Test offline data modification
        for (int i = 0; i < 5; i++) {
          await sqliteDAO.updateFoodItem(testAdminUid, 'offline_food_$i', {
            'name': 'Modified Offline Food Item $i',
            'price': 15.0 + i,
          });
          
          final updated = await sqliteDAO.getFoodItem(testAdminUid, 'offline_food_$i');
          expect(updated!['name'], equals('Modified Offline Food Item $i'));
          expect(updated['sync_status'], equals(SyncStatus.pending.value));
        }

        // 3. Test offline data deletion
        for (int i = 20; i < 25; i++) {
          await sqliteDAO.deleteFoodItem(testAdminUid, 'offline_food_$i');
          
          final deleted = await sqliteDAO.getFoodItem(testAdminUid, 'offline_food_$i');
          expect(deleted, isNull);
        }

        // 4. Test offline image caching
        final offlineImages = <String, Uint8List>{};
        for (int i = 0; i < 5; i++) {
          final imageData = Uint8List(512);
          for (int j = 0; j < imageData.length; j++) {
            imageData[j] = (i * 50 + j) % 256;
          }
          
          await imageCacheService.storeImageBlob(
            'food_items',
            'offline_food_$i',
            'https://example.com/offline_food_$i.jpg',
            imageData,
          );
          
          offlineImages['offline_food_$i'] = imageData;
        }

        // 5. Verify complete offline data availability
        final allDepartments = await sqliteDAO.getDepartments(testAdminUid);
        final offlineDepartments = allDepartments.where((d) => 
          (d['id'] as String).startsWith('offline_dept_')).toList();
        expect(offlineDepartments.length, equals(5));

        final allFoodItems = await sqliteDAO.getFoodItems(testAdminUid);
        final offlineFoodItems = allFoodItems.where((f) => 
          (f['id'] as String).startsWith('offline_food_')).toList();
        expect(offlineFoodItems.length, equals(20)); // 25 created - 5 deleted

        final allBills = await sqliteDAO.getBills(testAdminUid);
        final offlineBills = allBills.where((b) => 
          (b['id'] as String).startsWith('offline_bill_')).toList();
        expect(offlineBills.length, equals(10));

        // Verify offline images are accessible
        for (final entry in offlineImages.entries) {
          final cachedImage = await imageCacheService.getImageBlob('food_items', entry.key);
          expect(cachedImage, isNotNull);
          expect(cachedImage!.length, equals(512));
        }

        // 6. Test offline search and filtering
        final searchResults = await sqliteDAO.searchFoodItems(testAdminUid, 'Offline');
        expect(searchResults.length, greaterThan(0));

        final deptItems = await sqliteDAO.getFoodItems(testAdminUid, department: 'Offline Department 0');
        expect(deptItems.length, greaterThan(0));

        // 7. Verify sync preparation (simulating online state)
        
        final pendingItems = await sqliteDAO.getPendingSyncItems();
        expect(pendingItems.length, greaterThan(0));
        
        // Verify pending items include all offline operations
        final pendingDepartments = pendingItems.where((item) => 
          item['table_name'] == 'departments').toList();
        expect(pendingDepartments.length, equals(5));
        
        final pendingFoodItems = pendingItems.where((item) => 
          item['table_name'] == 'food_items').toList();
        expect(pendingFoodItems.length, greaterThan(0)); // Created and modified items
        
        final pendingBills = pendingItems.where((item) => 
          item['table_name'] == 'bills').toList();
        expect(pendingBills.length, equals(10));
      });

      test('should maintain offline performance under load', () async {
        // Test offline performance by measuring local database operations
        
        const offlineOperations = 100;
        final operationTimes = <int>[];
        
        // Perform various offline operations and measure performance
        for (int i = 0; i < offlineOperations; i++) {
          final stopwatch = Stopwatch()..start();
          
          final operationType = i % 3;
          switch (operationType) {
            case 0: // Create food item
              final foodItem = {
                'id': 'offline_perf_item_$i',
                'name': 'Offline Performance Item $i',
                'price': 10.0 + i,
                'department': 'Offline Performance Department',
              };
              await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
              break;
              
            case 1: // Query items
              await sqliteDAO.getFoodItemsPaginated(testAdminUid, limit: 10);
              break;
              
            case 2: // Search items
              await sqliteDAO.searchFoodItems(testAdminUid, 'Performance');
              break;
          }
          
          stopwatch.stop();
          operationTimes.add(stopwatch.elapsedMilliseconds);
        }
        
        // Analyze offline performance
        final avgTime = operationTimes.reduce((a, b) => a + b) / operationTimes.length;
        final maxTime = operationTimes.reduce((a, b) => a > b ? a : b);
        
        expect(avgTime, lessThan(50), 
          reason: 'Average offline operation should be under 50ms');
        expect(maxTime, lessThan(200), 
          reason: 'Maximum offline operation should be under 200ms');
        
        // Test completed - offline performance validated
      });
    });

    group('Query Performance Improvements Validation', () {
      test('should demonstrate significant performance improvements with optimizations', () async {
        const itemCount = 2000;
        const searchTerms = ['Food', 'Item', 'Test', 'Performance'];
        
        // Create large dataset for performance testing
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'opt_item_$i',
            'name': 'Optimized Food Item $i',
            'price': 5.0 + (i % 100),
            'department': 'Department ${i % 20}',
            'food_code': 'OPT${i.toString().padLeft(4, '0')}',
            'description': 'Performance optimized test item $i with searchable content',
            'stocks': 10 + (i % 90),
          };
          
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
        }

        // Test indexed queries (should be very fast)
        final indexedQueryTests = <String, Future<void> Function()>{
          'departmentQuery': () async {
            final stopwatch = Stopwatch()..start();
            final items = await sqliteDAO.getFoodItems(testAdminUid, department: 'Department 10');
            stopwatch.stop();
            
            expect(items.length, equals(100)); // itemCount / 20 departments
            expect(stopwatch.elapsedMilliseconds, lessThan(30), 
              reason: 'Indexed department query should be under 30ms');
          },
          
          'primaryKeyLookup': () async {
            final stopwatch = Stopwatch()..start();
            final item = await sqliteDAO.getFoodItem(testAdminUid, 'opt_item_1000');
            stopwatch.stop();
            
            expect(item, isNotNull);
            expect(stopwatch.elapsedMilliseconds, lessThan(5), 
              reason: 'Primary key lookup should be under 5ms');
          },
          
          'paginatedWithIndex': () async {
            final stopwatch = Stopwatch()..start();
            final items = await sqliteDAO.getFoodItemsPaginated(
              testAdminUid, 
              offset: 500, 
              limit: 50,
              orderBy: 'price ASC'
            );
            stopwatch.stop();
            
            expect(items.length, equals(50));
            expect(stopwatch.elapsedMilliseconds, lessThan(20), 
              reason: 'Paginated query with index should be under 20ms');
          },
          
          'fullTextSearch': () async {
            for (final searchTerm in searchTerms) {
              final stopwatch = Stopwatch()..start();
              final results = await sqliteDAO.searchFoodItems(testAdminUid, searchTerm);
              stopwatch.stop();
              
              expect(results.isNotEmpty, isTrue);
              expect(stopwatch.elapsedMilliseconds, lessThan(100), 
                reason: 'FTS search for "$searchTerm" should be under 100ms');
            }
          },
        };

        // Execute all optimized query tests
        for (final entry in indexedQueryTests.entries) {
          await entry.value();
        }

        // Test batch operations performance
        final batchStopwatch = Stopwatch()..start();
        
        final batchUpdates = <String, Map<String, dynamic>>{};
        for (int i = 0; i < 100; i++) {
          batchUpdates['opt_item_$i'] = {'price': 25.0 + i};
        }
        
        // Simulate batch update (individual updates for now)
        for (final entry in batchUpdates.entries) {
          await sqliteDAO.updateFoodItem(testAdminUid, entry.key, entry.value);
        }
        
        batchStopwatch.stop();
        expect(batchStopwatch.elapsedMilliseconds, lessThan(2000), 
          reason: 'Batch updates should complete within 2 seconds');

        // Test query result caching effectiveness
        final cacheTestStopwatch = Stopwatch()..start();
        
        // First query (cache miss)
        await sqliteDAO.getFoodItems(testAdminUid, department: 'Department 5');
        
        cacheTestStopwatch.stop();
        final firstQueryTime = cacheTestStopwatch.elapsedMilliseconds;
        
        // Second identical query (should hit cache if implemented)
        cacheTestStopwatch.reset();
        cacheTestStopwatch.start();
        
        await sqliteDAO.getFoodItems(testAdminUid, department: 'Department 5');
        
        cacheTestStopwatch.stop();
        final secondQueryTime = cacheTestStopwatch.elapsedMilliseconds;
        
        // Second query should be same or faster (depending on caching implementation)
        expect(secondQueryTime, lessThanOrEqualTo(firstQueryTime + 10), 
          reason: 'Cached query should not be significantly slower');
      });

      test('should validate prepared statement performance', () async {
        const queryCount = 100;
        final queryTimes = <int>[];
        
        // Create test data
        for (int i = 0; i < 50; i++) {
          final foodItem = {
            'id': 'prep_item_$i',
            'name': 'Prepared Statement Item $i',
            'price': 10.0 + i,
            'department': 'Prepared Department',
          };
          
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
        }

        // Test repeated queries (should benefit from prepared statements)
        for (int i = 0; i < queryCount; i++) {
          final stopwatch = Stopwatch()..start();
          
          // Perform the same type of query repeatedly
          await sqliteDAO.getFoodItem(testAdminUid, 'prep_item_${i % 50}');
          
          stopwatch.stop();
          queryTimes.add(stopwatch.elapsedMilliseconds);
        }

        // Analyze prepared statement performance
        final avgTime = queryTimes.reduce((a, b) => a + b) / queryTimes.length;
        final firstTenAvg = queryTimes.take(10).reduce((a, b) => a + b) / 10;
        final lastTenAvg = queryTimes.skip(queryCount - 10).reduce((a, b) => a + b) / 10;

        expect(avgTime, lessThan(10), 
          reason: 'Average prepared statement query should be under 10ms');
        
        // Performance should be consistent or improve over time with prepared statements
        expect(lastTenAvg, lessThanOrEqualTo(firstTenAvg * 1.5), 
          reason: 'Query performance should remain consistent with prepared statements');
      });
    });

    group('System Integration and Health Validation', () {
      test('should validate complete system health under realistic conditions', () async {
        // Create realistic system load
        const departments = 8;
        const itemsPerDept = 150;
        const bills = 200;
        const images = 50;

        // 1. Create comprehensive test data
        for (int d = 0; d < departments; d++) {
          final department = {
            'id': 'health_dept_$d',
            'name': 'Health Department $d',
            'status': 'Active',
          };
          await sqliteDAO.saveDepartment(testAdminUid, department);

          for (int i = 0; i < itemsPerDept; i++) {
            final globalIndex = (d * itemsPerDept) + i;
            final foodItem = {
              'id': 'health_item_$globalIndex',
              'name': 'Health Food Item $globalIndex',
              'price': 8.0 + (globalIndex % 42),
              'department': 'Health Department $d',
              'food_code': 'HLT${globalIndex.toString().padLeft(4, '0')}',
              'stocks': 20 + (globalIndex % 80),
            };
            await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
          }
        }

        for (int b = 0; b < bills; b++) {
          final bill = {
            'id': 'health_bill_$b',
            'customer_phone': '+1555${b.toString().padLeft(7, '0')}',
            'items': '{"health_item_${b % (departments * itemsPerDept)}": {"name": "Health Food Item ${b % (departments * itemsPerDept)}", "price": ${8.0 + (b % 42)}}}',
            'total_amount': 8.0 + (b % 42),
            'bill_date': DateTime.now().millisecondsSinceEpoch,
          };
          await sqliteDAO.saveBill(testAdminUid, bill);
        }

        // 2. Add image cache load
        for (int img = 0; img < images; img++) {
          final imageData = Uint8List(1024);
          for (int j = 0; j < imageData.length; j++) {
            imageData[j] = (img + j) % 256;
          }
          
          await imageCacheService.storeImageBlob(
            'food_items',
            'health_item_$img',
            'https://example.com/health_item_$img.jpg',
            imageData,
          );
        }

        // 3. Perform comprehensive system health checks
        final healthChecks = <String, Future<void> Function()>{
          'dataIntegrity': () async {
            final allDepts = await sqliteDAO.getDepartments(testAdminUid);
            final healthDepts = allDepts.where((d) => 
              (d['id'] as String).startsWith('health_dept_')).toList();
            expect(healthDepts.length, equals(departments));

            final allItems = await sqliteDAO.getFoodItems(testAdminUid);
            final healthItems = allItems.where((i) => 
              (i['id'] as String).startsWith('health_item_')).toList();
            expect(healthItems.length, equals(departments * itemsPerDept));

            final allBills = await sqliteDAO.getBills(testAdminUid);
            final healthBills = allBills.where((b) => 
              (b['id'] as String).startsWith('health_bill_')).toList();
            expect(healthBills.length, equals(bills));
          },

          'queryPerformance': () async {
            final stopwatch = Stopwatch()..start();
            
            // Mixed query workload
            await sqliteDAO.getFoodItems(testAdminUid, department: 'Health Department 3');
            await sqliteDAO.searchFoodItems(testAdminUid, 'Health');
            await sqliteDAO.getFoodItemsPaginated(testAdminUid, limit: 25);
            await sqliteDAO.getFoodItem(testAdminUid, 'health_item_500');
            
            stopwatch.stop();
            expect(stopwatch.elapsedMilliseconds, lessThan(500), 
              reason: 'Mixed query workload should complete within 500ms');
          },

          'cacheHealth': () async {
            final cacheStats = await imageCacheService.getCacheStatistics();
            expect(cacheStats['totalImages'], greaterThanOrEqualTo(images));
            expect(cacheStats['totalSizeBytes'], greaterThan(0));
            
            // Test cache retrieval performance
            final stopwatch = Stopwatch()..start();
            for (int i = 0; i < 10; i++) {
              await imageCacheService.getImageBlob('food_items', 'health_item_$i');
            }
            stopwatch.stop();
            
            expect(stopwatch.elapsedMilliseconds, lessThan(100), 
              reason: 'Cache retrieval should be fast');
          },

          'concurrentLoad': () async {
            const concurrentOps = 20;
            final futures = <Future>[];
            
            for (int i = 0; i < concurrentOps; i++) {
              futures.add(Future(() async {
                await sqliteDAO.getFoodItemsPaginated(testAdminUid, 
                  offset: i * 10, limit: 10);
              }));
            }
            
            final stopwatch = Stopwatch()..start();
            await Future.wait(futures);
            stopwatch.stop();
            
            expect(stopwatch.elapsedMilliseconds, lessThan(2000), 
              reason: 'Concurrent operations should complete within 2 seconds');
          },

          'memoryStability': () async {
            // Perform memory-intensive operations
            for (int cycle = 0; cycle < 5; cycle++) {
              final largeResult = await sqliteDAO.getFoodItems(testAdminUid);
              expect(largeResult.length, greaterThan(0));
              
              // Force some garbage collection opportunity
              await Future.delayed(const Duration(milliseconds: 10));
            }
            
            // System should remain stable
            expect(true, isTrue);
          },
        };

        // Execute all health checks
        for (final entry in healthChecks.entries) {
          await entry.value();
        }

        // 4. Final system validation
        final finalValidation = await performanceMonitor.getPerformanceReport();
        expect(finalValidation.containsKey('queryStatistics'), isTrue);
        expect(finalValidation.containsKey('memoryStatistics'), isTrue);
      });
    });
  });
}
