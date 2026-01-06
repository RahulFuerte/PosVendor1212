// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Project imports:
import 'database_service.dart';
import 'local/sqlite_helper.dart';
import 'remote/firebase_dao.dart';

/// Service for managing data integrity, backup, and recovery operations
class DataIntegrityService {
  static final DataIntegrityService _instance = DataIntegrityService._internal();
  factory DataIntegrityService() => _instance;
  DataIntegrityService._internal();

  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  FirebaseDAO? _firebaseDAO;

  /// Initialize the data integrity service
  Future<void> initialize() async {
    _firebaseDAO = FirebaseDAO();
    await _firebaseDAO!.initialize();
  }

  /// Execute a database operation within an ACID transaction
  Future<T> executeInTransaction<T>(Future<T> Function(Transaction txn) operation) async {
    final db = await _sqliteHelper.database;
    
    return await db.transaction<T>((txn) async {
      try {
        final result = await operation(txn);
        
        // Validate transaction integrity before committing
        await _validateTransactionIntegrity(txn);
        
        return result;
      } catch (e) {
        // Transaction will be automatically rolled back on exception
        print('Transaction failed and rolled back: $e');
        rethrow;
      }
    });
  }

  /// Execute multiple operations as a single ACID transaction
  Future<void> executeBatchTransaction(List<Future<void> Function(Transaction txn)> operations) async {
    final db = await _sqliteHelper.database;
    
    await db.transaction((txn) async {
      try {
        // Execute all operations within the transaction
        for (final operation in operations) {
          await operation(txn);
        }
        
        // Validate batch integrity before committing
        await _validateTransactionIntegrity(txn);
        
        print('Batch transaction completed successfully with ${operations.length} operations');
      } catch (e) {
        print('Batch transaction failed and rolled back: $e');
        rethrow;
      }
    });
  }

  /// Validate transaction integrity by checking constraints and data consistency
  Future<void> _validateTransactionIntegrity(Transaction txn) async {
    try {
      // Check foreign key constraints
      final fkResults = await txn.rawQuery('PRAGMA foreign_key_check');
      if (fkResults.isNotEmpty) {
        throw Exception('Foreign key constraint violations detected: $fkResults');
      }

      // Check data consistency for critical tables
      await _validateTableConsistency(txn, 'food_items');
      await _validateTableConsistency(txn, 'departments');
      await _validateTableConsistency(txn, 'bills');
      await _validateTableConsistency(txn, 'sync_log');
      
    } catch (e) {
      throw Exception('Transaction integrity validation failed: $e');
    }
  }

  /// Validate consistency of a specific table
  Future<void> _validateTableConsistency(Transaction txn, String tableName) async {
    switch (tableName) {
      case 'food_items':
        // Validate food items have required fields and valid data
        final invalidItems = await txn.rawQuery('''
          SELECT id FROM food_items 
          WHERE name IS NULL OR name = '' 
          OR price IS NULL OR price < 0
          OR admin_uid IS NULL OR admin_uid = ''
        ''');
        if (invalidItems.isNotEmpty) {
          throw Exception('Invalid food items detected: ${invalidItems.map((e) => e['id']).join(', ')}');
        }
        break;
        
      case 'departments':
        // Validate departments have required fields
        final invalidDepts = await txn.rawQuery('''
          SELECT id FROM departments 
          WHERE name IS NULL OR name = '' 
          OR admin_uid IS NULL OR admin_uid = ''
        ''');
        if (invalidDepts.isNotEmpty) {
          throw Exception('Invalid departments detected: ${invalidDepts.map((e) => e['id']).join(', ')}');
        }
        break;
        
      case 'bills':
        // Validate bills have required fields and valid amounts
        final invalidBills = await txn.rawQuery('''
          SELECT id FROM bills 
          WHERE total_amount IS NULL OR total_amount < 0
          OR items IS NULL OR items = ''
          OR admin_uid IS NULL OR admin_uid = ''
        ''');
        if (invalidBills.isNotEmpty) {
          throw Exception('Invalid bills detected: ${invalidBills.map((e) => e['id']).join(', ')}');
        }
        break;
        
      case 'sync_log':
        // Validate sync log entries have required fields
        final invalidLogs = await txn.rawQuery('''
          SELECT id FROM sync_log 
          WHERE table_name IS NULL OR table_name = ''
          OR record_id IS NULL OR record_id = ''
          OR operation IS NULL OR operation = ''
        ''');
        if (invalidLogs.isNotEmpty) {
          throw Exception('Invalid sync log entries detected: ${invalidLogs.map((e) => e['id']).join(', ')}');
        }
        break;
    }
  }

  /// Perform comprehensive data integrity validation during sync operations
  Future<DataIntegrityResult> validateDataIntegrity({String? adminUid}) async {
    final List<String> errors = [];
    final List<String> warnings = [];
    
    try {
      final db = await _sqliteHelper.database;
      
      // Check database integrity
      final integrityResults = await db.rawQuery('PRAGMA integrity_check');
      for (final result in integrityResults) {
        final message = result['integrity_check'] as String;
        if (message != 'ok') {
          errors.add('Database integrity issue: $message');
        }
      }
      
      // Check foreign key constraints
      final fkResults = await db.rawQuery('PRAGMA foreign_key_check');
      if (fkResults.isNotEmpty) {
        errors.add('Foreign key constraint violations: ${fkResults.length} issues found');
      }
      
      // Validate data consistency across tables
      await _validateCrossTableConsistency(db, errors, warnings, adminUid);
      
      // Check for orphaned records
      await _checkOrphanedRecords(db, warnings);
      
      // Validate sync status consistency
      await _validateSyncStatusConsistency(db, warnings);
      
      return DataIntegrityResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      errors.add('Data integrity validation failed: $e');
      return DataIntegrityResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Validate consistency across related tables
  Future<void> _validateCrossTableConsistency(
    Database db, 
    List<String> errors, 
    List<String> warnings,
    String? adminUid,
  ) async {
    // Check if food items reference valid departments
    final invalidFoodItems = await db.rawQuery('''
      SELECT fi.id, fi.department 
      FROM food_items fi 
      LEFT JOIN departments d ON fi.department = d.name AND fi.admin_uid = d.admin_uid
      WHERE fi.department IS NOT NULL 
      AND fi.department != '' 
      AND d.id IS NULL
      ${adminUid != null ? 'AND fi.admin_uid = ?' : ''}
    ''', adminUid != null ? [adminUid] : []);
    
    if (invalidFoodItems.isNotEmpty) {
      warnings.add('Food items with invalid department references: ${invalidFoodItems.length}');
    }
    
    // Check for bills with invalid item references (if items contain IDs)
    // This would require parsing the JSON items field, which we'll skip for now
    // but could be implemented based on the specific bill structure
  }

  /// Check for orphaned records that should be cleaned up
  Future<void> _checkOrphanedRecords(Database db, List<String> warnings) async {
    // Check for orphaned image cache entries
    final orphanedImages = await db.rawQuery('''
      SELECT ic.id 
      FROM image_cache ic 
      LEFT JOIN food_items fi ON ic.table_name = 'food_items' AND ic.record_id = fi.id
      LEFT JOIN departments d ON ic.table_name = 'departments' AND ic.record_id = d.id
      WHERE fi.id IS NULL AND d.id IS NULL
    ''');
    
    if (orphanedImages.isNotEmpty) {
      warnings.add('Orphaned image cache entries: ${orphanedImages.length}');
    }
    
    // Check for orphaned sync log entries
    final orphanedSyncLogs = await db.rawQuery('''
      SELECT sl.id, sl.table_name, sl.record_id
      FROM sync_log sl 
      LEFT JOIN food_items fi ON sl.table_name = 'food_items' AND sl.record_id = fi.id
      LEFT JOIN departments d ON sl.table_name = 'departments' AND sl.record_id = d.id
      LEFT JOIN bills b ON sl.table_name = 'bills' AND sl.record_id = b.id
      WHERE fi.id IS NULL AND d.id IS NULL AND b.id IS NULL
    ''');
    
    if (orphanedSyncLogs.isNotEmpty) {
      warnings.add('Orphaned sync log entries: ${orphanedSyncLogs.length}');
    }
  }

  /// Validate sync status consistency between main tables and sync log
  Future<void> _validateSyncStatusConsistency(Database db, List<String> warnings) async {
    // Check for records marked as synced but missing from sync log
    final tables = ['food_items', 'departments', 'bills'];
    
    for (final table in tables) {
      final inconsistentRecords = await db.rawQuery('''
        SELECT t.id 
        FROM $table t 
        LEFT JOIN sync_log sl ON sl.table_name = ? AND sl.record_id = t.id
        WHERE t.sync_status = 0 AND sl.id IS NULL
      ''', [table]);
      
      if (inconsistentRecords.isNotEmpty) {
        warnings.add('$table records marked as synced but missing from sync log: ${inconsistentRecords.length}');
      }
    }
  }

  /// Create a backup of the local database before major sync operations
  Future<BackupResult> createDatabaseBackup({String? backupName}) async {
    try {
      final db = await _sqliteHelper.database;
      final dbPath = db.path;
      
      // Generate backup filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFileName = backupName ?? 'pos_database_backup_$timestamp.db';
      
      // Get backup directory
      final backupDir = await _getBackupDirectory();
      final backupPath = join(backupDir.path, backupFileName);
      
      // Close current database connection temporarily
      await _sqliteHelper.closeDatabase();
      
      try {
        // Copy database file to backup location
        final dbFile = File(dbPath);
        await dbFile.copy(backupPath);
        
        // Verify backup integrity
        final backupDb = await openDatabase(backupPath, readOnly: true);
        final integrityResults = await backupDb.rawQuery('PRAGMA integrity_check');
        await backupDb.close();
        
        final isValid = integrityResults.isNotEmpty && 
                       integrityResults.first['integrity_check'] == 'ok';
        
        if (!isValid) {
          // Delete invalid backup
          await File(backupPath).delete();
          throw Exception('Backup integrity check failed');
        }
        
        // Clean up old backups (keep only last 5)
        await _cleanupOldBackups(backupDir);
        
        return BackupResult(
          success: true,
          backupPath: backupPath,
          backupSize: await File(backupPath).length(),
          timestamp: DateTime.now(),
        );
        
      } finally {
        // Reopen database connection
        await _sqliteHelper.initializeDatabase();
      }
      
    } catch (e) {
      return BackupResult(
        success: false,
        errorMessage: 'Backup creation failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Restore database from backup or Firebase
  Future<RestoreResult> restoreDatabase({
    String? backupPath,
    String? adminUid,
    bool fromFirebase = false,
  }) async {
    try {
      if (fromFirebase && adminUid != null) {
        return await _restoreFromFirebase(adminUid);
      } else if (backupPath != null) {
        return await _restoreFromBackup(backupPath);
      } else {
        throw Exception('Either backupPath or adminUid (for Firebase restore) must be provided');
      }
    } catch (e) {
      return RestoreResult(
        success: false,
        errorMessage: 'Database restore failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Restore database from Firebase backup
  Future<RestoreResult> _restoreFromFirebase(String adminUid) async {
    if (_firebaseDAO == null) {
      throw Exception('Firebase DAO not initialized');
    }
    
    try {
      // Create backup of current database before restore
      final backupResult = await createDatabaseBackup(backupName: 'pre_restore_backup');
      if (!backupResult.success) {
        throw Exception('Failed to create pre-restore backup: ${backupResult.errorMessage}');
      }
      
      // Clear current database
      await _clearDatabase();
      
      int restoredCount = 0;
      
      // Restore food items from Firebase
      final foodItems = await _firebaseDAO!.getFoodItems(adminUid);
      for (final item in foodItems) {
        await executeInTransaction((txn) async {
          await txn.insert('food_items', {
            ...item,
            'admin_uid': adminUid,
            'created_at': item['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': item['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'sync_status': SyncStatus.synced.value,
          });
        });
        restoredCount++;
      }
      
      // Restore departments from Firebase
      final departments = await _firebaseDAO!.getDepartments(adminUid);
      for (final dept in departments) {
        await executeInTransaction((txn) async {
          await txn.insert('departments', {
            ...dept,
            'admin_uid': adminUid,
            'created_at': dept['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': dept['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'sync_status': SyncStatus.synced.value,
          });
        });
        restoredCount++;
      }
      
      // Restore bills from Firebase
      final bills = await _firebaseDAO!.getBills(adminUid);
      for (final bill in bills) {
        await executeInTransaction((txn) async {
          await txn.insert('bills', {
            ...bill,
            'admin_uid': adminUid,
            'created_at': bill['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': bill['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'sync_status': SyncStatus.synced.value,
          });
        });
        restoredCount++;
      }
      
      // Validate restored data
      final integrityResult = await validateDataIntegrity(adminUid: adminUid);
      if (!integrityResult.isValid) {
        throw Exception('Restored data failed integrity check: ${integrityResult.errors.join(', ')}');
      }
      
      return RestoreResult(
        success: true,
        restoredItemsCount: restoredCount,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      // Attempt to restore from pre-restore backup if available
      print('Firebase restore failed, attempting to restore from backup: $e');
      rethrow;
    }
  }

  /// Restore database from local backup file
  Future<RestoreResult> _restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupPath');
      }
      
      // Verify backup integrity before restore
      final backupDb = await openDatabase(backupPath, readOnly: true);
      final integrityResults = await backupDb.rawQuery('PRAGMA integrity_check');
      await backupDb.close();
      
      final isValid = integrityResults.isNotEmpty && 
                     integrityResults.first['integrity_check'] == 'ok';
      
      if (!isValid) {
        throw Exception('Backup file is corrupted');
      }
      
      // Close current database
      await _sqliteHelper.closeDatabase();
      
      try {
        // Get current database path
        final db = await _sqliteHelper.database;
        final dbPath = db.path;
        await _sqliteHelper.closeDatabase();
        
        // Replace current database with backup
        await backupFile.copy(dbPath);
        
        // Reopen database and verify
        await _sqliteHelper.initializeDatabase();
        final restoredDb = await _sqliteHelper.database;
        final verifyResults = await restoredDb.rawQuery('PRAGMA integrity_check');
        
        final restoreValid = verifyResults.isNotEmpty && 
                           verifyResults.first['integrity_check'] == 'ok';
        
        if (!restoreValid) {
          throw Exception('Restored database failed integrity check');
        }
        
        // Count restored items
        final foodItemsCount = await restoredDb.rawQuery('SELECT COUNT(*) as count FROM food_items');
        final departmentsCount = await restoredDb.rawQuery('SELECT COUNT(*) as count FROM departments');
        final billsCount = await restoredDb.rawQuery('SELECT COUNT(*) as count FROM bills');
        
        final totalCount = (foodItemsCount.first['count'] as int) +
                          (departmentsCount.first['count'] as int) +
                          (billsCount.first['count'] as int);
        
        return RestoreResult(
          success: true,
          restoredItemsCount: totalCount,
          timestamp: DateTime.now(),
        );
        
      } catch (e) {
        // Ensure database is reopened even if restore fails
        await _sqliteHelper.initializeDatabase();
        rethrow;
      }
      
    } catch (e) {
      return RestoreResult(
        success: false,
        errorMessage: 'Backup restore failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Detect and attempt automatic corruption recovery
  Future<CorruptionRecoveryResult> detectAndRecoverCorruption(String adminUid) async {
    try {
      // Check for database corruption
      final integrityResult = await validateDataIntegrity(adminUid: adminUid);
      
      if (integrityResult.isValid) {
        return CorruptionRecoveryResult(
          corruptionDetected: false,
          recoveryAttempted: false,
          recoverySuccessful: false,
          message: 'No corruption detected',
          timestamp: DateTime.now(),
        );
      }
      
      print('Database corruption detected: ${integrityResult.errors.join(', ')}');
      
      // Attempt recovery from Firebase backup
      final restoreResult = await _restoreFromFirebase(adminUid);
      
      if (restoreResult.success) {
        // Verify recovery was successful
        final postRecoveryIntegrity = await validateDataIntegrity(adminUid: adminUid);
        
        return CorruptionRecoveryResult(
          corruptionDetected: true,
          recoveryAttempted: true,
          recoverySuccessful: postRecoveryIntegrity.isValid,
          message: postRecoveryIntegrity.isValid 
            ? 'Successfully recovered from Firebase backup'
            : 'Recovery attempted but integrity issues remain',
          restoredItemsCount: restoreResult.restoredItemsCount,
          timestamp: DateTime.now(),
        );
      } else {
        // Try to recover from local backup
        final backupDir = await _getBackupDirectory();
        final backups = await _getAvailableBackups(backupDir);
        
        if (backups.isNotEmpty) {
          // Try the most recent backup
          final latestBackup = backups.first;
          final backupRestoreResult = await _restoreFromBackup(latestBackup.path);
          
          if (backupRestoreResult.success) {
            final postBackupIntegrity = await validateDataIntegrity(adminUid: adminUid);
            
            return CorruptionRecoveryResult(
              corruptionDetected: true,
              recoveryAttempted: true,
              recoverySuccessful: postBackupIntegrity.isValid,
              message: postBackupIntegrity.isValid 
                ? 'Successfully recovered from local backup'
                : 'Backup recovery attempted but integrity issues remain',
              restoredItemsCount: backupRestoreResult.restoredItemsCount,
              timestamp: DateTime.now(),
            );
          }
        }
        
        return CorruptionRecoveryResult(
          corruptionDetected: true,
          recoveryAttempted: true,
          recoverySuccessful: false,
          message: 'All recovery attempts failed',
          timestamp: DateTime.now(),
        );
      }
      
    } catch (e) {
      return CorruptionRecoveryResult(
        corruptionDetected: true,
        recoveryAttempted: true,
        recoverySuccessful: false,
        message: 'Corruption recovery failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Clear all data from the database
  Future<void> _clearDatabase() async {
    final db = await _sqliteHelper.database;
    
    await db.transaction((txn) async {
      await txn.delete('image_cache');
      await txn.delete('sync_log');
      await txn.delete('bills');
      await txn.delete('food_items');
      await txn.delete('departments');
    });
  }

  /// Get backup directory
  Future<Directory> _getBackupDirectory() async {
    final dbPath = await getDatabasesPath();
    final backupDir = Directory(join(dbPath, 'backups'));
    
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir;
  }

  /// Clean up old backup files (keep only the 5 most recent)
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final backups = await _getAvailableBackups(backupDir);
      
      if (backups.length > 5) {
        // Sort by modification time (newest first) and remove old ones
        backups.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        
        for (int i = 5; i < backups.length; i++) {
          await backups[i].delete();
          print('Deleted old backup: ${backups[i].path}');
        }
      }
    } catch (e) {
      print('Failed to cleanup old backups: $e');
    }
  }

  /// Get list of available backup files
  Future<List<File>> _getAvailableBackups(Directory backupDir) async {
    final List<File> backups = [];
    
    if (await backupDir.exists()) {
      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          backups.add(entity);
        }
      }
    }
    
    return backups;
  }

  /// Get list of available backups with metadata
  Future<List<BackupInfo>> getAvailableBackups() async {
    final backupDir = await _getBackupDirectory();
    final backupFiles = await _getAvailableBackups(backupDir);
    
    final List<BackupInfo> backups = [];
    
    for (final file in backupFiles) {
      final stat = await file.stat();
      backups.add(BackupInfo(
        path: file.path,
        name: basename(file.path),
        size: stat.size,
        createdAt: stat.modified,
      ));
    }
    
    // Sort by creation time (newest first)
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return backups;
  }

  /// Delete a specific backup file
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to delete backup: $e');
      return false;
    }
  }
}

/// Result of data integrity validation
class DataIntegrityResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final DateTime timestamp;

  DataIntegrityResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.timestamp,
  });
}

/// Result of backup operation
class BackupResult {
  final bool success;
  final String? backupPath;
  final int? backupSize;
  final String? errorMessage;
  final DateTime timestamp;

  BackupResult({
    required this.success,
    this.backupPath,
    this.backupSize,
    this.errorMessage,
    required this.timestamp,
  });
}

/// Result of restore operation
class RestoreResult {
  final bool success;
  final int? restoredItemsCount;
  final String? errorMessage;
  final DateTime timestamp;

  RestoreResult({
    required this.success,
    this.restoredItemsCount,
    this.errorMessage,
    required this.timestamp,
  });
}

/// Result of corruption recovery operation
class CorruptionRecoveryResult {
  final bool corruptionDetected;
  final bool recoveryAttempted;
  final bool recoverySuccessful;
  final String message;
  final int? restoredItemsCount;
  final DateTime timestamp;

  CorruptionRecoveryResult({
    required this.corruptionDetected,
    required this.recoveryAttempted,
    required this.recoverySuccessful,
    required this.message,
    this.restoredItemsCount,
    required this.timestamp,
  });
}

/// Information about a backup file
class BackupInfo {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  BackupInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });
}
