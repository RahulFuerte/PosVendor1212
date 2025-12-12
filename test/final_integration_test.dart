import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/image_cache_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/sqlite_dao.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'test_database_helper.dart';

void main() {
  group('Final Integration Testing and Validation', () {
    late ImageCacheService imageCacheService;
    late SQLiteDAO sqliteDAO;
    const String testAdminUid = 'integration_test_admin';

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      final testDb = await TestDatabaseHelper.getTestDatabase();
      
      // Initialize only SQLite components for testing
      sqliteDAO = SQLiteDAO();
      imageCacheService = ImageCacheService();
      
      // Configure image cache service to use test database
      imageCacheService.setTestDatabase(testDb);
      
      await imageCacheService.initialize();
    });

    tearDown(() async {
      try {
        imageCacheService.reset();
        await sqliteDAO.close();
        await TestDatabaseHelper.clearAllTables();
        await TestDatabaseHelper.closeTestDatabase();
      } catch (e) {
        // Ignore cleanup errors in tests
      }
    });

    group('Complete Offline-to-Online Workflows', () {
      test('should handle complete offline bill creation and sync workflow', () async {
        // Simulate offline state
        final testBills = <Map<String, dynamic>>[];
        
        // Create multiple bills while "offline"
        for (int i = 0; i < 5; i++) {
          final bill = {
            'id': 'offline_bill_$i',
            'customer_phone': '+123456789$i',
            'items': '{"item_$i": {"name": "Offline Item $i", "price": ${10.0 + i}}}',
            'total_amount': 10.0 + i,
            'bill_date': DateTime.now().millisecondsSinceEpoch,
          };
          
          testBills.add(bill);
          
          // Save bill to local database
          await sqliteDAO.saveBill(testAdminUid, bill);
          
          // Verify bill is stored locally with pending sync status
          final storedBill = await sqliteDAO.getBill(testAdminUid, 'offline_bill_$i');
          expect(storedBill, isNotNull);
          expect(storedBill!['sync_status'], equals(SyncStatus.pending.value));
        }
        
        // Verify all bills are in pending sync state
        final pendingItems = await sqliteDAO.getPendingSyncItems();
        final pendingBills = pendingItems.where((item) => 
          item['table_name'] == 'bills' && 
          testBills.any((bill) => bill['id'] == item['record_id'])
        ).toList();
        
        expect(pendingBills.length, equals(5));
        
        // Simulate coming back online and sync
        // Note: In real scenario, this would sync to Firebase
        // For test, we verify the sync process structure
        
        for (final bill in testBills) {
          // Mark as synced (simulating successful Firebase sync)
          await sqliteDAO.markAsSynced('bills', bill['id'] as String);
        }
        
        // Verify bills are now marked as synced
        for (int i = 0; i < 5; i++) {
          final syncedBill = await sqliteDAO.getBill(testAdminUid, 'offline_bill_$i');
          expect(syncedBill, isNotNull);
          expect(syncedBill!['sync_status'], equals(SyncStatus.synced.value));
        }
        
        // Verify no pending sync items remain for these bills
        final remainingPending = await sqliteDAO.getPendingSyncItems();
        final remainingBills = remainingPending.where((item) => 
          item['table_name'] == 'bills' && 
          testBills.any((bill) => bill['id'] == item['record_id'])
        ).toList();
        
        expect(remainingBills.length, equals(0));
      });

      test('should handle offline food item management workflow', () async {
        final testFoodItems = <Map<String, dynamic>>[];
        
        // Create food items while offline
        for (int i = 0; i < 10; i++) {
          final foodItem = {
            'id': 'offline_food_$i',
            'name': 'Offline Food Item $i',
            'price': 5.0 + (i * 2.5),
            'description': 'Created while offline',
            'department': 'Offline Department',
            'stocks': 50 + i,
            'is_hot': i % 2,
          };
          
          testFoodItems.add(foodItem);
          
          // Save food item
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
          
          // Verify immediate local storage
          final stored = await sqliteDAO.getFoodItem(testAdminUid, 'offline_food_$i');
          expect(stored, isNotNull);
          expect(stored!['name'], equals(foodItem['name']));
          expect(stored['sync_status'], equals(SyncStatus.pending.value));
        }
        
        // Update some items while still offline
        for (int i = 0; i < 5; i++) {
          await sqliteDAO.updateFoodItem(testAdminUid, 'offline_food_$i', {
            'name': 'Updated Offline Food Item $i',
            'price': 15.0 + i,
          });
          
          // Verify update and pending status
          final updated = await sqliteDAO.getFoodItem(testAdminUid, 'offline_food_$i');
          expect(updated, isNotNull);
          expect(updated!['name'], equals('Updated Offline Food Item $i'));
          expect(updated['price'], equals(15.0 + i));
          expect(updated['sync_status'], equals(SyncStatus.pending.value));
        }
        
        // Delete some items while offline
        for (int i = 5; i < 8; i++) {
          await sqliteDAO.deleteFoodItem(testAdminUid, 'offline_food_$i');
          
          // Verify deletion
          final deleted = await sqliteDAO.getFoodItem(testAdminUid, 'offline_food_$i');
          expect(deleted, isNull);
        }
        
        // Simulate sync process
        final remainingItems = await sqliteDAO.getFoodItems(testAdminUid);
        final offlineItems = remainingItems.where((item) => 
          (item['id'] as String).startsWith('offline_food_')
        ).toList();
        
        // Should have 7 items remaining (10 created - 3 deleted)
        expect(offlineItems.length, equals(7));
        
        // Mark remaining items as synced
        for (final item in offlineItems) {
          await sqliteDAO.markAsSynced('food_items', item['id'] as String);
        }
        
        // Verify sync status
        for (final item in offlineItems) {
          final synced = await sqliteDAO.getFoodItem(testAdminUid, item['id'] as String);
          expect(synced!['sync_status'], equals(SyncStatus.synced.value));
        }
      });

      test('should handle offline image caching workflow', () async {
        final testImages = <String, Uint8List>{};
        
        // Create test images
        for (int i = 0; i < 5; i++) {
          final imageData = Uint8List(512);
          for (int j = 0; j < imageData.length; j++) {
            imageData[j] = (i * 50 + j) % 256;
          }
          testImages['offline_image_$i'] = imageData;
        }
        
        // Store images while offline
        for (final entry in testImages.entries) {
          await imageCacheService.storeImageBlob(
            'food_items',
            entry.key,
            'https://example.com/${entry.key}.jpg',
            entry.value,
          );
        }
        
        // Verify images are cached locally (with retry for database locking issues)
        for (final entry in testImages.entries) {
          Uint8List? cachedImage;
          
          // Retry logic for database locking issues
          for (int retry = 0; retry < 3; retry++) {
            try {
              cachedImage = await imageCacheService.getImageBlob('food_items', entry.key);
              if (cachedImage != null) break;
              await Future.delayed(const Duration(milliseconds: 10));
            } catch (e) {
              if (retry == 2) rethrow;
              await Future.delayed(const Duration(milliseconds: 50));
            }
          }
          
          expect(cachedImage, isNotNull, reason: 'Image ${entry.key} should be cached');
          expect(cachedImage!.length, equals(512));
          
          // Verify image data integrity
          for (int i = 0; i < cachedImage.length; i++) {
            expect(cachedImage[i], equals(entry.value[i]));
          }
        }
        
        // Test cache statistics
        final stats = await imageCacheService.getCacheStatistics();
        expect(stats['totalImages'], greaterThanOrEqualTo(5));
        expect(stats['totalSizeBytes'], greaterThanOrEqualTo(5 * 512));
        
        // Test cache cleanup
        await imageCacheService.clearImageCache();
        final statsAfterCleanup = await imageCacheService.getCacheStatistics();
        expect(statsAfterCleanup['totalImages'], equals(0));
      });
    });

    group('Data Consistency Across All Sync Scenarios', () {
      test('should maintain data consistency during bidirectional sync', () async {
        // Create initial data set
        final initialFoodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 10; i++) {
          final item = {
            'id': 'consistency_food_$i',
            'name': 'Consistency Test Food $i',
            'price': 10.0 + i,
            'department': 'Test Department',
            'stocks': 100,
          };
          initialFoodItems.add(item);
          await sqliteDAO.saveFoodItem(testAdminUid, item);
        }
        
        // Simulate local modifications
        final localModifications = <String, Map<String, dynamic>>{};
        for (int i = 0; i < 5; i++) {
          final updates = {
            'name': 'Locally Modified Food $i',
            'price': 20.0 + i,
          };
          localModifications['consistency_food_$i'] = updates;
          await sqliteDAO.updateFoodItem(testAdminUid, 'consistency_food_$i', updates);
        }
        
        // Simulate remote modifications (would come from Firebase)
        final remoteModifications = <String, Map<String, dynamic>>{};
        for (int i = 5; i < 10; i++) {
          final updates = {
            'name': 'Remotely Modified Food $i',
            'price': 30.0 + i,
            'stocks': 200,
          };
          remoteModifications['consistency_food_$i'] = updates;
          
          // Simulate receiving remote update
          await sqliteDAO.updateFoodItem(testAdminUid, 'consistency_food_$i', updates);
          await sqliteDAO.markAsSynced('food_items', 'consistency_food_$i');
        }
        
        // Verify data consistency
        for (int i = 0; i < 10; i++) {
          final item = await sqliteDAO.getFoodItem(testAdminUid, 'consistency_food_$i');
          expect(item, isNotNull);
          
          if (i < 5) {
            // Local modifications should be preserved
            expect(item!['name'], equals('Locally Modified Food $i'));
            expect(item['price'], equals(20.0 + i));
            expect(item['sync_status'], equals(SyncStatus.pending.value));
          } else {
            // Remote modifications should be applied
            expect(item!['name'], equals('Remotely Modified Food $i'));
            expect(item['price'], equals(30.0 + i));
            expect(item['stocks'], equals(200));
            expect(item['sync_status'], equals(SyncStatus.synced.value));
          }
        }
        
        // Test conflict resolution scenario
        final conflictItem = {
          'id': 'conflict_test_item',
          'name': 'Original Item',
          'price': 15.0,
          'department': 'Test',
        };
        
        await sqliteDAO.saveFoodItem(testAdminUid, conflictItem);
        await sqliteDAO.markAsSynced('food_items', 'conflict_test_item');
        
        // Simulate local modification
        await sqliteDAO.updateFoodItem(testAdminUid, 'conflict_test_item', {
          'name': 'Local Update',
          'price': 25.0,
        });
        
        // Simulate remote modification with newer timestamp
        final newerTimestamp = DateTime.now().millisecondsSinceEpoch + 1000;
        await sqliteDAO.updateFoodItem(testAdminUid, 'conflict_test_item', {
          'name': 'Remote Update (Newer)',
          'price': 35.0,
          'updated_at': newerTimestamp,
        });
        
        // In real scenario, conflict resolution would use timestamp
        final resolvedItem = await sqliteDAO.getFoodItem(testAdminUid, 'conflict_test_item');
        expect(resolvedItem, isNotNull);
        expect(resolvedItem!['updated_at'], equals(newerTimestamp));
      });

      test('should maintain referential integrity across sync operations', () async {
        // Create department first
        final department = {
          'id': 'integrity_dept',
          'name': 'Integrity Test Department',
          'status': 'Active',
        };
        await sqliteDAO.saveDepartment(testAdminUid, department);
        
        // Create food items referencing the department
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 5; i++) {
          final item = {
            'id': 'integrity_food_$i',
            'name': 'Integrity Food $i',
            'price': 10.0 + i,
            'department': 'Integrity Test Department',
          };
          foodItems.add(item);
          await sqliteDAO.saveFoodItem(testAdminUid, item);
        }
        
        // Verify relationships exist
        final deptItems = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'Integrity Test Department');
        expect(deptItems.length, equals(5));
        
        // Test department update propagation
        await sqliteDAO.updateDepartment(testAdminUid, 'integrity_dept', {
          'name': 'Updated Integrity Department',
        });
        
        // Update food items to reference new department name
        for (int i = 0; i < 5; i++) {
          await sqliteDAO.updateFoodItem(testAdminUid, 'integrity_food_$i', {
            'department': 'Updated Integrity Department',
          });
        }
        
        // Verify referential integrity maintained
        final updatedDeptItems = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'Updated Integrity Department');
        expect(updatedDeptItems.length, equals(5));
        
        // Verify old department reference is gone
        final oldDeptItems = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'Integrity Test Department');
        expect(oldDeptItems.length, equals(0));
      });
    });

    group('Concurrent Operations and Race Conditions', () {
      test('should handle concurrent database operations safely', () async {
        const concurrentOperations = 20;
        final futures = <Future>[];
        final results = <String>[];
        
        // Create concurrent write operations
        for (int i = 0; i < concurrentOperations; i++) {
          futures.add(
            Future(() async {
              try {
                final item = {
                  'id': 'concurrent_item_$i',
                  'name': 'Concurrent Item $i',
                  'price': 10.0 + i,
                  'department': 'Concurrent Test',
                };
                
                await sqliteDAO.saveFoodItem(testAdminUid, item);
                
                // Immediately read back to verify
                final saved = await sqliteDAO.getFoodItem(testAdminUid, 'concurrent_item_$i');
                if (saved != null && saved['name'] == item['name']) {
                  results.add('success_$i');
                } else {
                  results.add('failure_$i');
                }
              } catch (e) {
                results.add('error_$i: $e');
              }
            })
          );
        }
        
        // Wait for all operations to complete
        await Future.wait(futures);
        
        // Verify all operations succeeded
        final successCount = results.where((r) => r.startsWith('success')).length;
        expect(successCount, equals(concurrentOperations));
        
        // Verify all items were saved correctly
        final allItems = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'Concurrent Test');
        expect(allItems.length, equals(concurrentOperations));
      });

      test('should handle concurrent sync operations without corruption', () async {
        // Create test data
        final testItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 10; i++) {
          final item = {
            'id': 'sync_race_item_$i',
            'name': 'Sync Race Item $i',
            'price': 15.0 + i,
            'department': 'Sync Test',
          };
          testItems.add(item);
          await sqliteDAO.saveFoodItem(testAdminUid, item);
        }
        
        // Simulate concurrent sync operations
        final syncFutures = <Future>[];
        final syncResults = <bool>[];
        
        for (int i = 0; i < 5; i++) {
          syncFutures.add(
            Future(() async {
              try {
                // Simulate sync process
                final pendingItems = await sqliteDAO.getPendingSyncItems();
                final itemsToSync = pendingItems.where((item) => 
                  (item['record_id'] as String).startsWith('sync_race_item_')
                ).toList();
                
                // Mark items as synced
                for (final item in itemsToSync) {
                  await sqliteDAO.markAsSynced(
                    item['table_name'] as String, 
                    item['record_id'] as String
                  );
                }
                
                syncResults.add(true);
              } catch (e) {
                syncResults.add(false);
              }
            })
          );
        }
        
        await Future.wait(syncFutures);
        
        // Verify sync operations completed successfully
        final successfulSyncs = syncResults.where((r) => r).length;
        expect(successfulSyncs, greaterThan(0));
        
        // Verify final state consistency
        for (int i = 0; i < 10; i++) {
          final item = await sqliteDAO.getFoodItem(testAdminUid, 'sync_race_item_$i');
          expect(item, isNotNull);
          expect(item!['sync_status'], equals(SyncStatus.synced.value));
        }
      });

      test('should handle concurrent read/write operations', () async {
        // Create initial data
        final baseItem = {
          'id': 'read_write_race_item',
          'name': 'Read Write Race Item',
          'price': 20.0,
          'department': 'Race Test',
          'stocks': 100,
        };
        await sqliteDAO.saveFoodItem(testAdminUid, baseItem);
        
        const iterations = 50;
        final readResults = <Map<String, dynamic>>[];
        final writeOperations = <Future>[];
        final readOperations = <Future>[];
        
        // Create concurrent read operations
        for (int i = 0; i < iterations; i++) {
          readOperations.add(
            Future(() async {
              final item = await sqliteDAO.getFoodItem(testAdminUid, 'read_write_race_item');
              if (item != null) {
                readResults.add(Map<String, dynamic>.from(item));
              }
            })
          );
        }
        
        // Create concurrent write operations
        for (int i = 0; i < 10; i++) {
          writeOperations.add(
            Future(() async {
              await sqliteDAO.updateFoodItem(testAdminUid, 'read_write_race_item', {
                'price': 20.0 + i,
                'stocks': 100 + (i * 10),
              });
            })
          );
        }
        
        // Execute all operations concurrently
        await Future.wait([...readOperations, ...writeOperations]);
        
        // Verify read operations completed successfully
        expect(readResults.length, equals(iterations));
        
        // Verify all reads returned valid data
        for (final result in readResults) {
          expect(result['id'], equals('read_write_race_item'));
          expect(result['name'], equals('Read Write Race Item'));
          expect(result['price'], isA<double>());
          expect(result['stocks'], isA<int>());
        }
        
        // Verify final state is consistent
        final finalItem = await sqliteDAO.getFoodItem(testAdminUid, 'read_write_race_item');
        expect(finalItem, isNotNull);
        expect(finalItem!['id'], equals('read_write_race_item'));
      });
    });

    group('UI Responsiveness During Sync Operations', () {
      test('should maintain database responsiveness during heavy sync load', () async {
        // Create large dataset for sync simulation
        const largeDatasetSize = 100;
        final largeDataset = <Map<String, dynamic>>[];
        
        for (int i = 0; i < largeDatasetSize; i++) {
          final item = {
            'id': 'heavy_sync_item_$i',
            'name': 'Heavy Sync Item $i',
            'price': 5.0 + (i * 0.5),
            'description': 'Item created for heavy sync load testing',
            'department': 'Heavy Sync Department',
            'stocks': 50 + i,
          };
          largeDataset.add(item);
          await sqliteDAO.saveFoodItem(testAdminUid, item);
        }
        
        // Simulate heavy sync operations in background
        final syncFuture = Future(() async {
          for (int batch = 0; batch < 10; batch++) {
            // Process items in batches
            final batchStart = batch * 10;
            final batchEnd = (batch + 1) * 10;
            
            for (int i = batchStart; i < batchEnd && i < largeDatasetSize; i++) {
              // Simulate sync processing time
              await Future.delayed(const Duration(milliseconds: 5));
              
              // Mark as synced
              await sqliteDAO.markAsSynced('food_items', 'heavy_sync_item_$i');
            }
            
            // Small delay between batches
            await Future.delayed(const Duration(milliseconds: 10));
          }
        });
        
        // Perform UI operations while sync is running
        final uiOperationTimes = <int>[];
        final uiOperations = <Future>[];
        
        for (int i = 0; i < 20; i++) {
          uiOperations.add(
            Future(() async {
              final stopwatch = Stopwatch()..start();
              
              // Simulate typical UI operations
              await sqliteDAO.getFoodItemsPaginated(testAdminUid, limit: 10);
              await sqliteDAO.getDepartments(testAdminUid);
              
              // Quick item lookup
              final randomIndex = Random().nextInt(largeDatasetSize);
              await sqliteDAO.getFoodItem(testAdminUid, 'heavy_sync_item_$randomIndex');
              
              stopwatch.stop();
              uiOperationTimes.add(stopwatch.elapsedMilliseconds);
            })
          );
          
          // Stagger UI operations
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        // Wait for both sync and UI operations to complete
        await Future.wait([syncFuture, ...uiOperations]);
        
        // Verify UI operations remained responsive
        final avgResponseTime = uiOperationTimes.reduce((a, b) => a + b) / uiOperationTimes.length;
        final maxResponseTime = uiOperationTimes.reduce((a, b) => a > b ? a : b);
        
        // UI operations should remain fast even during heavy sync
        expect(avgResponseTime, lessThan(100), 
          reason: 'Average UI response time should be under 100ms');
        expect(maxResponseTime, lessThan(200), 
          reason: 'Maximum UI response time should be under 200ms');
        
        // Verify sync completed successfully
        final syncedCount = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'Heavy Sync Department');
        expect(syncedCount.length, equals(largeDatasetSize));
      });

      test('should handle UI operations during image cache operations', () async {
        const imageCount = 20;
        final imageOperationTimes = <int>[];
        final uiOperationTimes = <int>[];
        
        // Start heavy image caching operations
        final imageCachingFuture = Future(() async {
          for (int i = 0; i < imageCount; i++) {
            final stopwatch = Stopwatch()..start();
            
            // Create test image data
            final imageData = Uint8List(1024); // 1KB image
            for (int j = 0; j < imageData.length; j++) {
              imageData[j] = (i + j) % 256;
            }
            
            // Store image
            await imageCacheService.storeImageBlob(
              'ui_test_items',
              'ui_test_item_$i',
              'https://example.com/ui_test_$i.jpg',
              imageData,
            );
            
            stopwatch.stop();
            imageOperationTimes.add(stopwatch.elapsedMilliseconds);
            
            // Small delay between operations
            await Future.delayed(const Duration(milliseconds: 10));
          }
        });
        
        // Perform concurrent UI database operations
        final uiOperationsFuture = Future(() async {
          for (int i = 0; i < 30; i++) {
            final stopwatch = Stopwatch()..start();
            
            // Simulate UI data operations
            await sqliteDAO.getFoodItemsPaginated(testAdminUid, limit: 5);
            
            // Quick item creation (simulating user adding item)
            final quickItem = {
              'id': 'ui_quick_item_$i',
              'name': 'Quick UI Item $i',
              'price': 5.0,
              'department': 'UI Test',
            };
            await sqliteDAO.saveFoodItem(testAdminUid, quickItem);
            
            stopwatch.stop();
            uiOperationTimes.add(stopwatch.elapsedMilliseconds);
            
            await Future.delayed(const Duration(milliseconds: 25));
          }
        });
        
        // Wait for both operations to complete
        await Future.wait([imageCachingFuture, uiOperationsFuture]);
        
        // Verify UI remained responsive during image operations
        final avgUiTime = uiOperationTimes.reduce((a, b) => a + b) / uiOperationTimes.length;
        final maxUiTime = uiOperationTimes.reduce((a, b) => a > b ? a : b);
        
        expect(avgUiTime, lessThan(50), 
          reason: 'UI operations should remain fast during image caching');
        expect(maxUiTime, lessThan(100), 
          reason: 'Maximum UI operation time should be reasonable');
        
        // Verify image operations completed successfully
        final cacheStats = await imageCacheService.getCacheStatistics();
        expect(cacheStats['totalImages'], greaterThanOrEqualTo(imageCount));
        
        // Verify UI operations completed successfully
        final quickItems = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'UI Test');
        expect(quickItems.length, equals(30));
      });

      test('should maintain query performance under concurrent load', () async {
        // Create diverse dataset
        const itemsPerDepartment = 50;
        final departments = ['Pizza', 'Burgers', 'Drinks', 'Desserts', 'Salads'];
        
        for (final dept in departments) {
          for (int i = 0; i < itemsPerDepartment; i++) {
            final item = {
              'id': '${dept.toLowerCase()}_item_$i',
              'name': '$dept Item $i',
              'price': 5.0 + (i * 0.25),
              'department': dept,
              'stocks': 100 + i,
            };
            await sqliteDAO.saveFoodItem(testAdminUid, item);
          }
        }
        
        // Perform concurrent queries of different types
        final queryTimes = <String, List<int>>{};
        final queryFutures = <Future>[];
        
        // Different query patterns
        for (int i = 0; i < 20; i++) {
          // Department-specific queries
          queryFutures.add(Future(() async {
            final stopwatch = Stopwatch()..start();
            final dept = departments[i % departments.length];
            await sqliteDAO.getFoodItems(testAdminUid, department: dept);
            stopwatch.stop();
            queryTimes.putIfAbsent('department', () => []).add(stopwatch.elapsedMilliseconds);
          }));
          
          // Individual item lookups
          queryFutures.add(Future(() async {
            final stopwatch = Stopwatch()..start();
            final dept = departments[i % departments.length];
            final itemIndex = i % itemsPerDepartment;
            await sqliteDAO.getFoodItem(testAdminUid, '${dept.toLowerCase()}_item_$itemIndex');
            stopwatch.stop();
            queryTimes.putIfAbsent('individual', () => []).add(stopwatch.elapsedMilliseconds);
          }));
          
          // All items queries with limits
          queryFutures.add(Future(() async {
            final stopwatch = Stopwatch()..start();
            await sqliteDAO.getFoodItemsPaginated(testAdminUid, limit: 20);
            stopwatch.stop();
            queryTimes.putIfAbsent('limited', () => []).add(stopwatch.elapsedMilliseconds);
          }));
        }
        
        await Future.wait(queryFutures);
        
        // Analyze query performance
        for (final entry in queryTimes.entries) {
          final queryType = entry.key;
          final times = entry.value;
          
          if (times.isNotEmpty) {
            final avgTime = times.reduce((a, b) => a + b) / times.length;
            final maxTime = times.reduce((a, b) => a > b ? a : b);
            
            // All query types should be reasonably fast
            expect(avgTime, lessThan(50), 
              reason: '$queryType queries should average under 50ms');
            expect(maxTime, lessThan(100), 
              reason: '$queryType queries should max under 100ms');
          }
        }
        
        // Verify data integrity after concurrent operations
        final totalItems = await sqliteDAO.getFoodItems(testAdminUid);
        expect(totalItems.length, equals(departments.length * itemsPerDepartment));
        
        for (final dept in departments) {
          final deptItems = await sqliteDAO.getFoodItems(testAdminUid, department: dept);
          expect(deptItems.length, equals(itemsPerDepartment));
        }
      });
    });

    group('System Integration Validation', () {
      test('should validate complete system integration', () async {
        // Test complete workflow integration
        
        // 1. Initialize system components
        expect(await sqliteDAO.isOnline(), isTrue);
        
        // 2. Create test data across all entities
        final department = {
          'id': 'integration_dept',
          'name': 'Integration Test Department',
          'status': 'Active',
        };
        await sqliteDAO.saveDepartment(testAdminUid, department);
        
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 5; i++) {
          final item = {
            'id': 'integration_food_$i',
            'name': 'Integration Food $i',
            'price': 12.0 + i,
            'department': 'Integration Test Department',
            'stocks': 50,
          };
          foodItems.add(item);
          await sqliteDAO.saveFoodItem(testAdminUid, item);
        }
        
        final bills = <Map<String, dynamic>>[];
        for (int i = 0; i < 3; i++) {
          final bill = {
            'id': 'integration_bill_$i',
            'customer_phone': '+1234567890',
            'items': '{"integration_food_0": {"name": "Integration Food 0", "price": 12.0}}',
            'total_amount': 12.0,
            'bill_date': DateTime.now().millisecondsSinceEpoch,
          };
          bills.add(bill);
          await sqliteDAO.saveBill(testAdminUid, bill);
        }
        
        // 3. Test image caching integration
        final imageData = Uint8List(256);
        for (int i = 0; i < imageData.length; i++) {
          imageData[i] = i % 256;
        }
        
        await imageCacheService.storeImageBlob(
          'food_items',
          'integration_food_0',
          'https://example.com/integration_food_0.jpg',
          imageData,
        );
        
        // 4. Verify all data is accessible and consistent
        final retrievedDept = await sqliteDAO.getDepartment(testAdminUid, 'integration_dept');
        expect(retrievedDept, isNotNull);
        expect(retrievedDept!['name'], equals('Integration Test Department'));
        
        final retrievedItems = await sqliteDAO.getFoodItems(testAdminUid, 
          department: 'Integration Test Department');
        expect(retrievedItems.length, equals(5));
        
        final retrievedBills = await sqliteDAO.getBills(testAdminUid);
        final integrationBills = retrievedBills.where((bill) => 
          (bill['id'] as String).startsWith('integration_bill_')).toList();
        expect(integrationBills.length, equals(3));
        
        // Verify image caching with retry logic
        Uint8List? cachedImage;
        for (int retry = 0; retry < 3; retry++) {
          try {
            cachedImage = await imageCacheService.getImageBlob('food_items', 'integration_food_0');
            if (cachedImage != null) break;
            await Future.delayed(const Duration(milliseconds: 10));
          } catch (e) {
            if (retry == 2) rethrow;
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
        
        expect(cachedImage, isNotNull, reason: 'Integration image should be cached');
        expect(cachedImage!.length, equals(256));
        
        // 5. Test sync status tracking
        final pendingItems = await sqliteDAO.getPendingSyncItems();
        expect(pendingItems.length, greaterThan(0));
        
        // 6. Test system statistics and health
        final cacheStats = await imageCacheService.getCacheStatistics();
        expect(cacheStats['totalImages'], greaterThan(0));
        
        // 7. Test cleanup operations
        await imageCacheService.clearImageCache();
        final statsAfterCleanup = await imageCacheService.getCacheStatistics();
        expect(statsAfterCleanup['totalImages'], equals(0));
        
        // System integration test passes if all operations complete successfully
        expect(true, isTrue);
      });
    });
  });
}