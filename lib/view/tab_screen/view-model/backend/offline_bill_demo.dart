import 'dart:convert';
import 'database_service.dart';
import 'unified_database_service.dart';
import 'offline_bill_manager.dart';

/// Demonstration class showing how to use the offline bill management system
/// This class should be used with a DatabaseService instance from dependency injection
class OfflineBillDemo {
  final UnifiedDatabaseService _databaseService;
  
  /// Constructor that accepts a DatabaseService instance from Provider
  /// Use: OfflineBillDemo(Provider.of<DatabaseService>(context, listen: false) as UnifiedDatabaseService)
  OfflineBillDemo(this._databaseService);
  
  /// Factory constructor that creates instance from Provider context
  /// This is the recommended way to create the demo instance
  factory OfflineBillDemo.fromProvider(DatabaseService databaseService) {
    return OfflineBillDemo(databaseService as UnifiedDatabaseService);
  }
  
  /// Initialize the database service (if not already initialized)
  Future<void> initialize() async {
    await _databaseService.initialize();
  }

  /// Demonstrate storing a bill offline
  Future<void> demonstrateOfflineBillStorage() async {
    const String adminUid = 'demo_admin_123';
    
    // Create a sample bill
    final Map<String, dynamic> sampleBill = {
      'id': 'offline_bill_${DateTime.now().millisecondsSinceEpoch}',
      'customer_phone': '+1234567890',
      'items': jsonEncode([
        {
          'name': 'Coffee',
          'price': 4.50,
          'quantity': 2,
          'total': 9.00,
        },
        {
          'name': 'Sandwich',
          'price': 8.00,
          'quantity': 1,
          'total': 8.00,
        }
      ]),
      'total_amount': 17.00,
      'bill_date': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      // Store bill (will automatically handle offline storage if no connection)
      await _databaseService.saveBill(adminUid, sampleBill);
      print('✅ Bill stored successfully: ${sampleBill['id']}');
      
      // Check offline bills count
      final offlineCount = await _databaseService.getOfflineBillsCount(adminUid);
      print('📊 Offline bills pending sync: $offlineCount');
      
      // Get offline bills
      final offlineBills = await _databaseService.getOfflineBills(adminUid);
      print('📋 Offline bills: ${offlineBills.length} found');
      
      for (final bill in offlineBills) {
        print('   - Bill ID: ${bill['id']}, Amount: \$${bill['total_amount']}');
      }
      
    } catch (e) {
      print('❌ Error storing bill: $e');
    }
  }

  /// Demonstrate manual sync of offline bills
  Future<void> demonstrateManualSync() async {
    const String adminUid = 'demo_admin_123';
    
    try {
      print('🔄 Starting manual sync of offline bills...');
      
      final result = await _databaseService.manualSyncOfflineBills(adminUid);
      
      if (result.success) {
        print('✅ Manual sync completed successfully!');
        print('📊 Bills synced: ${result.billsSynced}');
      } else {
        print('❌ Manual sync failed: ${result.errorMessage}');
      }
      
    } catch (e) {
      print('❌ Error during manual sync: $e');
    }
  }

  /// Demonstrate automatic sync monitoring
  Future<void> demonstrateAutomaticSync() async {
    const String adminUid = 'demo_admin_123';
    
    print('👂 Listening for automatic sync events...');
    
    // Listen to sync status changes
    _databaseService.offlineBillSyncStatusStream.listen((status) {
      switch (status) {
        case OfflineBillSyncStatus.stored:
          print('📦 Bill stored offline');
          break;
        case OfflineBillSyncStatus.syncing:
          print('🔄 Automatic sync in progress...');
          break;
        case OfflineBillSyncStatus.completed:
          print('✅ Automatic sync completed');
          break;
        case OfflineBillSyncStatus.failed:
          print('❌ Automatic sync failed');
          break;
        case OfflineBillSyncStatus.manualSyncStarted:
          print('🔄 Manual sync started');
          break;
        case OfflineBillSyncStatus.manualSyncCompleted:
          print('✅ Manual sync completed');
          break;
        case OfflineBillSyncStatus.manualSyncFailed:
          print('❌ Manual sync failed');
          break;
      }
    });

    // Listen to sync results
    _databaseService.offlineBillSyncResultStream.listen((result) {
      if (result.success) {
        print('📊 Sync result: ${result.billsSynced} bills synced at ${result.timestamp}');
      } else {
        print('❌ Sync error: ${result.errorMessage}');
      }
    });

    // Trigger automatic sync (will happen when connectivity is restored)
    try {
      await _databaseService.syncOfflineBills(adminUid);
    } catch (e) {
      print('Note: Automatic sync will trigger when connectivity is available');
    }
  }

  /// Demonstrate getting sync statistics
  Future<void> demonstrateSyncStatistics() async {
    const String adminUid = 'demo_admin_123';
    
    try {
      final stats = await _databaseService.getOfflineBillSyncStatistics(adminUid);
      
      print('📊 Offline Bill Sync Statistics:');
      print('   - Offline bills pending: ${stats['offlineBillsCount'] ?? 0}');
      print('   - Synced bills: ${stats['syncedBillsCount'] ?? 0}');
      print('   - Total bills: ${stats['totalBillsCount'] ?? 0}');
      print('   - Connected: ${stats['isConnected'] ?? false}');
      print('   - Currently syncing: ${stats['isSyncing'] ?? false}');
      
    } catch (e) {
      print('❌ Error getting statistics: $e');
    }
  }

  /// Demonstrate checking individual bill sync status
  Future<void> demonstrateBillSyncStatus(String billId) async {
    const String adminUid = 'demo_admin_123';
    
    try {
      final isSynced = await _databaseService.isBillSynced(adminUid, billId);
      
      if (isSynced) {
        print('✅ Bill $billId is synced to Firebase');
      } else {
        print('⏳ Bill $billId is pending sync');
      }
      
    } catch (e) {
      print('❌ Error checking bill sync status: $e');
    }
  }

  /// Demonstrate force sync of a specific bill
  Future<void> demonstrateForceSyncBill(String billId) async {
    const String adminUid = 'demo_admin_123';
    
    try {
      print('🔄 Force syncing bill $billId...');
      
      final success = await _databaseService.forceSyncOfflineBill(adminUid, billId);
      
      if (success) {
        print('✅ Bill $billId force synced successfully');
      } else {
        print('❌ Failed to force sync bill $billId');
      }
      
    } catch (e) {
      print('❌ Error force syncing bill: $e');
    }
  }

  /// Run a complete demonstration
  Future<void> runCompleteDemo() async {
    print('🚀 Starting Offline Bill Management Demo\n');
    
    try {
      // Initialize
      print('1️⃣ Initializing database service...');
      await initialize();
      print('✅ Database service initialized\n');
      
      // Store offline bill
      print('2️⃣ Demonstrating offline bill storage...');
      await demonstrateOfflineBillStorage();
      print('');
      
      // Show statistics
      print('3️⃣ Showing sync statistics...');
      await demonstrateSyncStatistics();
      print('');
      
      // Setup automatic sync monitoring
      print('4️⃣ Setting up automatic sync monitoring...');
      await demonstrateAutomaticSync();
      print('');
      
      // Manual sync
      print('5️⃣ Demonstrating manual sync...');
      await demonstrateManualSync();
      print('');
      
      print('✅ Demo completed successfully!');
      
    } catch (e) {
      print('❌ Demo failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _databaseService.close();
  }
}

/// Example usage function
/// Note: In a real app, you would get the DatabaseService from Provider:
/// final databaseService = Provider.of<DatabaseService>(context, listen: false);
/// final demo = OfflineBillDemo.fromProvider(databaseService);
Future<void> runOfflineBillDemo() async {
  // For demo purposes, create a new instance (not recommended in production)
  final databaseService = UnifiedDatabaseService();
  await databaseService.initialize();
  final demo = OfflineBillDemo(databaseService);
  
  try {
    await demo.runCompleteDemo();
  } finally {
    demo.dispose();
    await databaseService.close();
  }
}