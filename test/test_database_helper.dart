import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

class TestDatabaseHelper {
  static Database? _database;
  static String? _testDbPath;
  static int _instanceCounter = 0;

  static Future<Database> getTestDatabase() async {
    // Always create a new database instance for each test to avoid concurrency issues
    await closeTestDatabase();
    
    // Create a unique test database path with instance counter and random component
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _instanceCounter++;
    final randomId = DateTime.now().microsecondsSinceEpoch % 10000;
    _testDbPath = join(Directory.systemTemp.path, 'test_pos_database_${timestamp}_${_instanceCounter}_$randomId.db');
    
    _database = await openDatabase(
      _testDbPath!,
      version: 2,
      onCreate: _createTables,
      onOpen: (db) async {
        // Enable WAL mode for better concurrent access
        await db.execute('PRAGMA journal_mode=WAL');
        // Set busy timeout to handle locking
        await db.execute('PRAGMA busy_timeout=30000');
        // Disable foreign key constraints for tests to avoid constraint violations
        await db.execute('PRAGMA foreign_keys=OFF');
      },
    );
    
    return _database!;
  }

  static Future<void> _createTables(Database db, int version) async {
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

    // Create image_cache table for managing cached images (without foreign key constraint)
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

    // Create test tables for performance and integration tests
    await db.execute('''
      CREATE TABLE test_items (
        id TEXT PRIMARY KEY,
        name TEXT,
        image_blob BLOB,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE ui_test_items (
        id TEXT PRIMARY KEY,
        name TEXT,
        image_blob BLOB,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE health_test (
        id TEXT PRIMARY KEY,
        name TEXT,
        image_blob BLOB,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE mixed_test (
        id TEXT PRIMARY KEY,
        name TEXT,
        image_blob BLOB,
        created_at INTEGER
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_food_items_admin_uid ON food_items(admin_uid)');
    await db.execute('CREATE INDEX idx_departments_admin_uid ON departments(admin_uid)');
    await db.execute('CREATE INDEX idx_bills_admin_uid ON bills(admin_uid)');
    await db.execute('CREATE INDEX idx_sync_log_table_record ON sync_log(table_name, record_id)');
    await db.execute('CREATE INDEX idx_image_cache_record ON image_cache(table_name, record_id)');
  }

  static Future<void> clearAllTables() async {
    if (_database == null) return;
    
    await _database!.delete('food_items');
    await _database!.delete('departments');
    await _database!.delete('bills');
    await _database!.delete('sync_log');
    await _database!.delete('image_cache');
    await _database!.delete('test_items');
    await _database!.delete('ui_test_items');
    await _database!.delete('health_test');
    await _database!.delete('mixed_test');
  }

  static Future<void> closeTestDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Clean up test database file
    if (_testDbPath != null) {
      try {
        final file = File(_testDbPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
      _testDbPath = null;
    }
  }
}