import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_dao.dart';
import 'shared_preferences.dart';
import 'database_maintenance_service.dart';

class SQLiteHelper {
  static final SQLiteHelper _instance = SQLiteHelper._internal();
  static Database? _database;
  static const int _currentVersion = 1; // Force recreation for tax column addition
  static const String _migrationCompleteKey = 'initial_migration_complete';
  
  // Database maintenance service (lazy initialization to avoid circular dependency)
  DatabaseMaintenanceService? _maintenanceService;

  factory SQLiteHelper() {
    return _instance;
  }

  SQLiteHelper._internal();
  
  /// Get or create the maintenance service instance
  DatabaseMaintenanceService get _getMaintenanceService {
    if (_maintenanceService == null) {
      _maintenanceService = DatabaseMaintenanceService();
      _maintenanceService!.initialize(this);
    }
    return _maintenanceService!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pos_database.db');
    return await openDatabase(
      path,
      version: _currentVersion,
      onCreate: _createTables,
      onUpgrade: _migrateTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create food_items table with BLOB image storage
    await db.execute('''
      CREATE TABLE food_items (
        id TEXT PRIMARY KEY,
        admin_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT,
        image_blob BLOB,
        description TEXT,
        food_code TEXT,
        department TEXT,
        stocks INTEGER,
        is_hot BOOLEAN DEFAULT 0,
        tax TEXT DEFAULT 'GST',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        firebase_id TEXT
      )
    ''');

    // Create departments table with BLOB image storage
    await db.execute('''
      CREATE TABLE departments (
        id TEXT PRIMARY KEY,
        admin_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        image_url TEXT,
        image_blob BLOB,
        status TEXT DEFAULT 'Active',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        firebase_id TEXT
      )
    ''');

    // Create bills table for offline bill storage
    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY,
        admin_uid TEXT NOT NULL,
        customer_phone TEXT,
        items TEXT NOT NULL,
        total_amount REAL NOT NULL,
        bill_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        firebase_id TEXT
      )
    ''');

    // Create sync_log table for tracking sync operations
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');

    // Create image_cache table for managing cached images
    await db.execute('''
      CREATE TABLE image_cache (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        image_url TEXT NOT NULL,
        image_blob BLOB,
        file_size INTEGER,
        cached_at INTEGER NOT NULL,
        last_accessed INTEGER NOT NULL
      )
    ''');

    // Create comprehensive indexes for better performance
    await _createPerformanceIndexes(db);
  }

  Future<void> _migrateTables(Database db, int oldVersion, int newVersion) async {
    print('Migrating database from version $oldVersion to $newVersion');
    
    // Handle specific migration paths
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrateToVersion(db, version);
    }
  }

  Future<void> _migrateToVersion(Database db, int version) async {
    print('Migrating to version $version');
    
    switch (version) {
      case 2:
        await _migrateToVersion2(db);
        break;
      case 3:
        await _migrateToVersion3(db);
        break;
      case 4:
        await _migrateToVersion4(db);
        break;
      // Add future migration cases here
      default:
        print('No migration needed for version $version');
    }
  }

  Future<void> _migrateToVersion2(Database db) async {
    // Migration to version 2: Add performance indexes
    try {
      // Add new indexes for better performance
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_sync_status ON food_items(sync_status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_departments_sync_status ON departments(sync_status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bills_sync_status ON bills(sync_status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date)');
      
      // Add migration metadata table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS migration_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          version INTEGER NOT NULL,
          migration_name TEXT NOT NULL,
          executed_at INTEGER NOT NULL,
          success BOOLEAN DEFAULT 1
        )
      ''');
      
      // Log this migration
      await db.insert('migration_log', {
        'version': 2,
        'migration_name': 'add_performance_indexes',
        'executed_at': DateTime.now().millisecondsSinceEpoch,
        'success': 1,
      });
      
      print('Successfully migrated to version 2');
    } catch (e) {
      print('Error migrating to version 2: $e');
      // Log failed migration
      try {
        await db.insert('migration_log', {
          'version': 2,
          'migration_name': 'add_performance_indexes',
          'executed_at': DateTime.now().millisecondsSinceEpoch,
          'success': 0,
        });
      } catch (logError) {
        print('Error logging failed migration: $logError');
      }
      rethrow;
    }
  }

  Future<void> _migrateToVersion3(Database db) async {
    // Migration to version 3: Add tax column to food_items table
    try {
      // Add tax column to food_items table if it doesn't exist
      try {
        await db.execute('ALTER TABLE food_items ADD COLUMN tax TEXT DEFAULT "GST"');
        print('Added tax column to food_items table');
      } catch (e) {
        // Column might already exist, check if it's a duplicate column error
        if (e.toString().contains('duplicate column name')) {
          print('Tax column already exists in food_items table');
        } else {
          print('Error adding tax column: $e');
          // If we can't add the column, recreate the table
          await _recreateFoodItemsTable(db);
        }
      }
      
      // Log this migration
      await db.insert('migration_log', {
        'version': 3,
        'migration_name': 'add_tax_column',
        'executed_at': DateTime.now().millisecondsSinceEpoch,
        'success': 1,
      });
      
      print('Successfully migrated to version 3');
    } catch (e) {
      print('Error migrating to version 3: $e');
      // Log failed migration
      try {
        await db.insert('migration_log', {
          'version': 3,
          'migration_name': 'add_tax_column',
          'executed_at': DateTime.now().millisecondsSinceEpoch,
          'success': 0,
        });
      } catch (logError) {
        print('Error logging failed migration: $logError');
      }
      rethrow;
    }
  }

  Future<void> _recreateFoodItemsTable(Database db) async {
    print('Recreating food_items table with tax column...');
    
    // Create backup of existing data
    final existingData = await db.query('food_items');
    
    // Drop the old table
    await db.execute('DROP TABLE IF EXISTS food_items');
    
    // Create new table with tax column
    await db.execute('''
      CREATE TABLE food_items (
        id TEXT PRIMARY KEY,
        admin_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT,
        image_blob BLOB,
        description TEXT,
        food_code TEXT,
        department TEXT,
        stocks INTEGER,
        is_hot BOOLEAN DEFAULT 0,
        tax TEXT DEFAULT 'GST',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        firebase_id TEXT
      )
    ''');
    
    // Restore data with default tax value
    for (final row in existingData) {
      final newRow = Map<String, dynamic>.from(row);
      newRow['tax'] = 'GST'; // Add default tax value
      await db.insert('food_items', newRow);
    }
    
    // Recreate indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_admin_uid ON food_items(admin_uid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_sync_status ON food_items(sync_status)');
    
    print('Successfully recreated food_items table with ${existingData.length} records');
  }

  Future<void> _migrateToVersion4(Database db) async {
    // Migration to version 4: Force recreation to ensure tax column exists
    try {
      print('Migrating to version 4: Ensuring tax column exists...');
      
      // Check if tax column exists
      bool taxColumnExists = false;
      try {
        await db.rawQuery('SELECT tax FROM food_items LIMIT 1');
        taxColumnExists = true;
        print('Tax column already exists');
      } catch (e) {
        if (e.toString().contains('no such column: tax')) {
          print('Tax column missing, will recreate table');
          taxColumnExists = false;
        } else {
          print('Error checking tax column: $e');
          rethrow;
        }
      }
      
      if (!taxColumnExists) {
        await _recreateFoodItemsTable(db);
      }
      
      // Re-enable tax field mapping now that column exists
      print('Tax column migration complete, re-enabling tax field mapping');
      
      // Log this migration
      await db.insert('migration_log', {
        'version': 4,
        'migration_name': 'ensure_tax_column_exists',
        'executed_at': DateTime.now().millisecondsSinceEpoch,
        'success': 1,
      });
      
      print('Successfully migrated to version 4');
    } catch (e) {
      print('Error migrating to version 4: $e');
      // Log failed migration
      try {
        await db.insert('migration_log', {
          'version': 4,
          'migration_name': 'ensure_tax_column_exists',
          'executed_at': DateTime.now().millisecondsSinceEpoch,
          'success': 0,
        });
      } catch (logError) {
        print('Error logging failed migration: $logError');
      }
      rethrow;
    }
  }

  Future<void> _dropAllTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS food_items');
    await db.execute('DROP TABLE IF EXISTS departments');
    await db.execute('DROP TABLE IF EXISTS bills');
    await db.execute('DROP TABLE IF EXISTS sync_log');
    await db.execute('DROP TABLE IF EXISTS image_cache');
  }

  // Database initialization method
  Future<void> initializeDatabase() async {
    await database;
    await _checkAndPerformInitialMigration();
    
    // Schedule automatic maintenance after initialization
    await _getMaintenanceService.scheduleAutomaticMaintenance();
  }

  // Check if initial migration from Firebase is needed
  Future<void> _checkAndPerformInitialMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationComplete = prefs.getBool(_migrationCompleteKey) ?? false;
      
      if (!migrationComplete) {
        print('Performing initial data migration from Firebase...');
        await performInitialDataMigration();
        await prefs.setBool(_migrationCompleteKey, true);
        print('Initial data migration completed');
      }
    } catch (e) {
      // In test environment, SharedPreferences might not be available
      // Skip migration check and continue
      print('SharedPreferences not available (likely test environment), skipping migration check: $e');
    }
  }

  // Perform initial data migration from Firebase to SQLite
  Future<void> performInitialDataMigration() async {
    try {
      final myPrefs = MySharedPreferences();
      String adminUid = await myPrefs.uID ?? '';
      final prefs = await SharedPreferences.getInstance();
      // If no UID found, try to get current user UID and save it
      if (adminUid.isEmpty) {
        final firebaseDao = FirebaseDAO();
        final currentUser = await firebaseDao.getCurrentUser();
        if (currentUser != null) {
          adminUid = currentUser['uid'];
await prefs.setString('uid', adminUid);
        }
      }
      
      if (adminUid.isEmpty) {
        print('No admin UID found, skipping initial migration');
        return;
      }

      final firebaseDao = FirebaseDAO();
      final db = await database;
      
      // Check if Firebase is accessible
      final isOnline = await firebaseDao.isOnline();
      if (!isOnline) {
        print('Firebase not accessible, skipping initial migration');
        return;
      }

      print('Starting migration for admin: $adminUid');
      
      // Migrate food items
      await _migrateFoodItems(firebaseDao, db, adminUid);
      
      // Migrate departments
      await _migrateDepartments(firebaseDao, db, adminUid);
      
      // Migrate recent bills (last 30 days)
      await _migrateRecentBills(firebaseDao, db, adminUid);
      
      print('Initial data migration completed successfully');
      
    } catch (e) {
      print('Error during initial data migration: $e');
      // Don't rethrow - allow app to continue with empty local database
      // In test environment, this is expected behavior
    }
  }

  Future<void> _migrateFoodItems(FirebaseDAO firebaseDao, Database db, String adminUid) async {
    try {
      print('Migrating food items...');
      final foodItems = await firebaseDao.getFoodItems(adminUid);
      
      for (final item in foodItems) {
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
            'sync_status': 0, // Mark as synced
            'firebase_id': item['firebase_id'] ?? item['id'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      print('Migrated ${foodItems.length} food items');
    } catch (e) {
      print('Error migrating food items: $e');
    }
  }

  Future<void> _migrateDepartments(FirebaseDAO firebaseDao, Database db, String adminUid) async {
    try {
      print('Migrating departments...');
      final departments = await firebaseDao.getDepartments(adminUid);
      
      for (final dept in departments) {
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
            'sync_status': 0, // Mark as synced
            'firebase_id': dept['firebase_id'] ?? dept['id'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      print('Migrated ${departments.length} departments');
    } catch (e) {
      print('Error migrating departments: $e');
    }
  }

  Future<void> _migrateRecentBills(FirebaseDAO firebaseDao, Database db, String adminUid) async {
    try {
      print('Migrating recent bills...');
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final bills = await firebaseDao.getBills(adminUid, startDate: thirtyDaysAgo);
      
      for (final bill in bills) {
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
            'sync_status': 0, // Mark as synced
            'firebase_id': bill['firebase_id'] ?? bill['id'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      print('Migrated ${bills.length} recent bills');
    } catch (e) {
      print('Error migrating recent bills: $e');
    }
  }

  // Force re-migration (for testing or data refresh)
  Future<void> forceReMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationCompleteKey, false);
      await _checkAndPerformInitialMigration();
    } catch (e) {
      print('SharedPreferences not available for force re-migration: $e');
      // In test environment, just perform migration directly
      await performInitialDataMigration();
    }
  }

  // Get migration status
  Future<bool> isMigrationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationCompleteKey) ?? false;
    } catch (e) {
      print('SharedPreferences not available for migration status check: $e');
      return false; // Assume not complete in test environment
    }
  }

  // Get migration history
  Future<List<Map<String, dynamic>>> getMigrationHistory() async {
    try {
      final db = await database;
      return await db.query(
        'migration_log',
        orderBy: 'executed_at DESC',
      );
    } catch (e) {
      print('Error getting migration history: $e');
      return [];
    }
  }

  // Close database connection
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Get database instance for direct access
  Future<Database> getDatabaseInstance() async {
    return await database;
  }

  // Create comprehensive performance indexes
  Future<void> _createPerformanceIndexes(Database db) async {
    try {
      // Basic admin_uid indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_admin_uid ON food_items(admin_uid)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_departments_admin_uid ON departments(admin_uid)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bills_admin_uid ON bills(admin_uid)');
      
      // Performance indexes for frequently queried columns
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_name ON food_items(name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_department ON food_items(department)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_price ON food_items(price)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_food_code ON food_items(food_code)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_stocks ON food_items(stocks)');
      
      // Composite indexes for common query patterns
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_admin_dept ON food_items(admin_uid, department)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_admin_name ON food_items(admin_uid, name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_admin_price ON food_items(admin_uid, price)');
      
      // Sync status indexes for performance
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_sync_status ON food_items(sync_status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_departments_sync_status ON departments(sync_status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bills_sync_status ON bills(sync_status)');
      
      // Date-based indexes for bills
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bills_admin_date ON bills(admin_uid, bill_date)');
      
      // Sync log indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_log_table_record ON sync_log(table_name, record_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(sync_status)');
      
      // Image cache indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_image_cache_record ON image_cache(table_name, record_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_image_cache_accessed ON image_cache(last_accessed)');
      
      // Full-text search indexes for better search performance
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS food_items_fts USING fts5(
            id, name, description, food_code, department,
            content='food_items',
            content_rowid='rowid'
          )
        ''');
        
        // Populate FTS table
        await db.execute('''
          INSERT OR REPLACE INTO food_items_fts(id, name, description, food_code, department)
          SELECT id, name, description, food_code, department FROM food_items
        ''');
        
        print('FTS5 search indexes created successfully');
      } catch (ftsError) {
        print('FTS5 not available, skipping full-text search indexes: $ftsError');
        // Create fallback search indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_name_search ON food_items(name COLLATE NOCASE)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_food_items_description_search ON food_items(description COLLATE NOCASE)');
        print('Fallback search indexes created');
      }
      
      print('Performance indexes created successfully');
    } catch (e) {
      print('Error creating performance indexes: $e');
      // Don't fail database creation if indexes fail
    }
  }

  // Create database index manager for runtime optimization
  Future<void> createPerformanceIndexes() async {
    final db = await database;
    await _createPerformanceIndexes(db);
  }

  // Analyze query performance and suggest optimizations
  Future<Map<String, dynamic>> analyzeQueryPerformance() async {
    final db = await database;
    final analysis = <String, dynamic>{};
    
    try {
      // Check if indexes are being used
      final explainQueries = [
        'EXPLAIN QUERY PLAN SELECT * FROM food_items WHERE admin_uid = ?',
        'EXPLAIN QUERY PLAN SELECT * FROM food_items WHERE department = ?',
        'EXPLAIN QUERY PLAN SELECT * FROM food_items WHERE name LIKE ?',
        'EXPLAIN QUERY PLAN SELECT * FROM bills WHERE admin_uid = ? AND bill_date > ?',
      ];
      
      for (final query in explainQueries) {
        final result = await db.rawQuery(query, ['test']);
        analysis[query] = result;
      }
      
      // Get table statistics
      final foodItemsCount = await db.rawQuery('SELECT COUNT(*) as count FROM food_items');
      final departmentsCount = await db.rawQuery('SELECT COUNT(*) as count FROM departments');
      final billsCount = await db.rawQuery('SELECT COUNT(*) as count FROM bills');
      
      analysis['tableStats'] = {
        'food_items': foodItemsCount.first['count'],
        'departments': departmentsCount.first['count'],
        'bills': billsCount.first['count'],
      };
      
      return analysis;
    } catch (e) {
      print('Error analyzing query performance: $e');
      return {'error': e.toString()};
    }
  }

  // Force database recreation (for fixing schema issues)
  Future<void> recreateDatabase() async {
    try {
      // Close existing database
      await closeDatabase();
      
      // Delete database file
      String path = join(await getDatabasesPath(), 'pos_database.db');
      await deleteDatabase(path);
      
      // Reset migration flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationCompleteKey, false);
      
      // Reinitialize database
      _database = await _initDatabase();
      await _checkAndPerformInitialMigration();
      
      print('Database recreated successfully');
    } catch (e) {
      print('Error recreating database: $e');
      rethrow;
    }
  }

  // Database Maintenance Operations
  
  /// Perform comprehensive database maintenance
  Future<MaintenanceResult> performDatabaseMaintenance({
    bool forceVacuum = false,
    bool forceIntegrityCheck = false,
    bool cleanupOldData = true,
    bool optimizeIndexes = true,
  }) async {
    return await _getMaintenanceService.performMaintenance(
      forceVacuum: forceVacuum,
      forceIntegrityCheck: forceIntegrityCheck,
      cleanupOldData: cleanupOldData,
      optimizeIndexes: optimizeIndexes,
    );
  }
  
  /// Perform automatic database vacuum operation
  Future<VacuumResult> performDatabaseVacuum() async {
    return await _getMaintenanceService.performVacuum();
  }
  
  /// Perform database integrity check
  Future<IntegrityCheckResult> performDatabaseIntegrityCheck() async {
    return await _getMaintenanceService.performIntegrityCheck();
  }
  
  /// Get database size information and monitoring data
  Future<DatabaseSizeInfo> getDatabaseSizeInformation() async {
    return await _getMaintenanceService.getDatabaseSizeInfo();
  }
  
  /// Perform data cleanup operations
  Future<DataCleanupResult> performDatabaseCleanup() async {
    return await _getMaintenanceService.performDataCleanup();
  }
  
  /// Optimize database indexes
  Future<IndexOptimizationResult> optimizeDatabaseIndexes() async {
    return await _getMaintenanceService.optimizeIndexes();
  }
  
  /// Get maintenance history
  Future<List<Map<String, dynamic>>> getMaintenanceHistory({int limit = 50}) async {
    return await _getMaintenanceService.getMaintenanceHistory(limit: limit);
  }
  
  /// Schedule automatic maintenance (called during initialization)
  Future<void> scheduleAutomaticMaintenance() async {
    await _getMaintenanceService.scheduleAutomaticMaintenance();
  }
}