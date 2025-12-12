import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_helper.dart';
import 'firebase_dao.dart';
import 'shared_preferences.dart';

/// Service for handling database migrations and schema updates
class DatabaseMigrationService {
  static const String _lastMigrationCheckKey = 'last_migration_check';
  static const String _schemaVersionKey = 'schema_version';
  
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final FirebaseDAO _firebaseDao = FirebaseDAO();
  final MySharedPreferences _prefs = MySharedPreferences();

  /// Check and perform any pending migrations
  Future<void> checkAndPerformMigrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastMigrationCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check for migrations daily
      if (now - lastCheck > Duration(days: 1).inMilliseconds) {
        await _performPendingMigrations();
        await prefs.setInt(_lastMigrationCheckKey, now);
      }
    } catch (e) {
      print('Error checking migrations: $e');
    }
  }

  /// Perform incremental data sync from Firebase
  Future<void> performIncrementalSync({DateTime? since}) async {
    try {
      final adminUid = await _prefs.uID;
      if (adminUid.isEmpty) return;

      final isOnline = await _firebaseDao.isOnline();
      if (!isOnline) {
        print('Offline - skipping incremental sync');
        return;
      }

      print('Performing incremental sync...');
      
      // Get last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTime = since?.millisecondsSinceEpoch ?? 
          prefs.getInt('last_incremental_sync') ?? 
          DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;

      await _syncIncrementalFoodItems(adminUid, DateTime.fromMillisecondsSinceEpoch(lastSyncTime));
      await _syncIncrementalDepartments(adminUid, DateTime.fromMillisecondsSinceEpoch(lastSyncTime));
      await _syncIncrementalBills(adminUid, DateTime.fromMillisecondsSinceEpoch(lastSyncTime));

      // Update last sync timestamp
      await prefs.setInt('last_incremental_sync', DateTime.now().millisecondsSinceEpoch);
      
      print('Incremental sync completed');
    } catch (e) {
      print('Error during incremental sync: $e');
    }
  }

  /// Validate data integrity between local and remote
  Future<Map<String, dynamic>> validateDataIntegrity() async {
    final results = <String, dynamic>{
      'food_items': {'local': 0, 'remote': 0, 'discrepancies': []},
      'departments': {'local': 0, 'remote': 0, 'discrepancies': []},
      'bills': {'local': 0, 'remote': 0, 'discrepancies': []},
    };

    try {
      final adminUid = await _prefs.uID;
      if (adminUid.isEmpty) return results;

      final db = await _sqliteHelper.database;
      
      // Validate food items
      await _validateTableIntegrity(db, 'food_items', adminUid, results);
      
      // Validate departments
      await _validateTableIntegrity(db, 'departments', adminUid, results);
      
      // Validate bills
      await _validateTableIntegrity(db, 'bills', adminUid, results);
      
    } catch (e) {
      print('Error validating data integrity: $e');
      results['error'] = e.toString();
    }

    return results;
  }

  /// Backup local database before major operations
  Future<String?> createDatabaseBackup() async {
    try {
      final db = await _sqliteHelper.database;
      final prefs = await SharedPreferences.getInstance();
      
      // Create backup data structure
      final backup = <String, dynamic>{
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': 2,
        'tables': {},
      };

      // Backup each table
      final tables = ['food_items', 'departments', 'bills', 'sync_log', 'image_cache'];
      
      for (final table in tables) {
        try {
          final data = await db.query(table);
          backup['tables'][table] = data;
        } catch (e) {
          print('Error backing up table $table: $e');
        }
      }

      // Store backup in SharedPreferences (for small datasets)
      // For larger datasets, consider writing to file
      final backupJson = jsonEncode(backup);
      final backupKey = 'db_backup_${DateTime.now().millisecondsSinceEpoch}';
      
      await prefs.setString(backupKey, backupJson);
      await prefs.setString('latest_backup_key', backupKey);
      
      print('Database backup created: $backupKey');
      return backupKey;
      
    } catch (e) {
      print('Error creating database backup: $e');
      return null;
    }
  }

  /// Restore database from backup
  Future<bool> restoreFromBackup(String backupKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString(backupKey);
      
      if (backupJson == null) {
        print('Backup not found: $backupKey');
        return false;
      }

      final backup = jsonDecode(backupJson) as Map<String, dynamic>;
      final db = await _sqliteHelper.database;
      
      // Restore each table
      final tables = backup['tables'] as Map<String, dynamic>;
      
      for (final entry in tables.entries) {
        final tableName = entry.key;
        final tableData = entry.value as List<dynamic>;
        
        try {
          // Clear existing data
          await db.delete(tableName);
          
          // Insert backup data
          for (final row in tableData) {
            await db.insert(tableName, row as Map<String, dynamic>);
          }
          
          print('Restored table $tableName with ${tableData.length} records');
        } catch (e) {
          print('Error restoring table $tableName: $e');
        }
      }
      
      print('Database restored from backup: $backupKey');
      return true;
      
    } catch (e) {
      print('Error restoring from backup: $e');
      return false;
    }
  }

  /// Clean up old backups
  Future<void> cleanupOldBackups({int keepCount = 5}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('db_backup_')).toList();
      
      // Sort by timestamp (newest first)
      keys.sort((a, b) {
        final timestampA = int.tryParse(a.split('_').last) ?? 0;
        final timestampB = int.tryParse(b.split('_').last) ?? 0;
        return timestampB.compareTo(timestampA);
      });
      
      // Remove old backups
      if (keys.length > keepCount) {
        final toRemove = keys.skip(keepCount);
        for (final key in toRemove) {
          await prefs.remove(key);
        }
        print('Cleaned up ${toRemove.length} old backups');
      }
    } catch (e) {
      print('Error cleaning up old backups: $e');
    }
  }

  // Private helper methods

  Future<void> _performPendingMigrations() async {
    // Check for schema updates or data migrations
    // This could include checking Firebase for new data structure changes
    print('Checking for pending migrations...');
    
    // Example: Check if new fields were added to Firebase collections
    await _checkForSchemaUpdates();
  }

  Future<void> _checkForSchemaUpdates() async {
    try {
      // This could check a Firebase collection for schema version info
      // For now, we'll just ensure our local schema is up to date
      final prefs = await SharedPreferences.getInstance();
      final currentSchemaVersion = prefs.getInt(_schemaVersionKey) ?? 1;
      const latestSchemaVersion = 2;
      
      if (currentSchemaVersion < latestSchemaVersion) {
        print('Schema update needed: $currentSchemaVersion -> $latestSchemaVersion');
        // Perform schema updates here
        await prefs.setInt(_schemaVersionKey, latestSchemaVersion);
      }
    } catch (e) {
      print('Error checking schema updates: $e');
    }
  }

  Future<void> _syncIncrementalFoodItems(String adminUid, DateTime since) async {
    try {
      // In a real implementation, Firebase would need to support timestamp queries
      // For now, we'll sync all items and check timestamps locally
      final remoteItems = await _firebaseDao.getFoodItems(adminUid);
      final db = await _sqliteHelper.database;
      
      for (final item in remoteItems) {
        final updatedAt = item['updated_at'] ?? 0;
        if (updatedAt > since.millisecondsSinceEpoch) {
          await db.insert(
            'food_items',
            {
              'id': item['id'],
              'admin_uid': adminUid,
              'name': item['name'],
              'price': item['price'],
              'image_path': item['imagePath'] ?? item['image_path'],
              'description': item['description'],
              'food_code': item['foodCode'] ?? item['food_code'],
              'department': item['department'],
              'stocks': item['stocks'] ?? 0,
              'is_hot': item['isHot'] == true || item['is_hot'] == true ? 1 : 0,
              'tax': item['tax'] ?? 'GST',
              'created_at': item['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
              'updated_at': item['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
              'sync_status': 0,
              'firebase_id': item['firebase_id'] ?? item['id'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (e) {
      print('Error syncing incremental food items: $e');
    }
  }

  Future<void> _syncIncrementalDepartments(String adminUid, DateTime since) async {
    try {
      final remoteDepts = await _firebaseDao.getDepartments(adminUid);
      final db = await _sqliteHelper.database;
      
      for (final dept in remoteDepts) {
        final updatedAt = dept['updated_at'] ?? 0;
        if (updatedAt > since.millisecondsSinceEpoch) {
          await db.insert(
            'departments',
            {
              'id': dept['id'],
              'admin_uid': adminUid,
              'name': dept['name'],
              'image_url': dept['imageUrl'] ?? dept['image_url'],
              'status': dept['status'] ?? 'Active',
              'created_at': dept['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
              'updated_at': dept['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
              'sync_status': 0,
              'firebase_id': dept['firebase_id'] ?? dept['id'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (e) {
      print('Error syncing incremental departments: $e');
    }
  }

  Future<void> _syncIncrementalBills(String adminUid, DateTime since) async {
    try {
      final remoteBills = await _firebaseDao.getBills(adminUid, startDate: since);
      final db = await _sqliteHelper.database;
      
      for (final bill in remoteBills) {
        await db.insert(
          'bills',
          {
            'id': bill['id'],
            'admin_uid': adminUid,
            'customer_phone': bill['customerPhone'] ?? bill['customer_phone'],
            'items': bill['items'] is String ? bill['items'] : bill['items'].toString(),
            'total_amount': bill['totalAmount'] ?? bill['total_amount'] ?? 0.0,
            'bill_date': bill['bill_date'] ?? DateTime.now().millisecondsSinceEpoch,
            'created_at': bill['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': bill['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'sync_status': 0,
            'firebase_id': bill['firebase_id'] ?? bill['id'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      print('Error syncing incremental bills: $e');
    }
  }

  Future<void> _validateTableIntegrity(Database db, String tableName, String adminUid, Map<String, dynamic> results) async {
    try {
      // Count local records
      final localCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE admin_uid = ?', [adminUid])
      ) ?? 0;
      
      results[tableName]['local'] = localCount;
      
      // Count remote records (this is a simplified check)
      int remoteCount = 0;
      try {
        if (tableName == 'food_items') {
          final items = await _firebaseDao.getFoodItems(adminUid);
          remoteCount = items.length;
        } else if (tableName == 'departments') {
          final depts = await _firebaseDao.getDepartments(adminUid);
          remoteCount = depts.length;
        } else if (tableName == 'bills') {
          final bills = await _firebaseDao.getBills(adminUid);
          remoteCount = bills.length;
        }
      } catch (e) {
        print('Could not get remote count for $tableName: $e');
      }
      
      results[tableName]['remote'] = remoteCount;
      
      // Check for discrepancies
      if (localCount != remoteCount) {
        results[tableName]['discrepancies'].add({
          'type': 'count_mismatch',
          'local': localCount,
          'remote': remoteCount,
        });
      }
      
    } catch (e) {
      print('Error validating $tableName integrity: $e');
      results[tableName]['error'] = e.toString();
    }
  }
}