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

  /// Create a test database for testing
  static Future<Database> createTestDatabase() async {
    return await getTestDatabase();
  }

  /// Insert test food items for testing
  static Future<void> insertTestFoodItems(Database db, String adminUid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final testItems = [
      {
        'id': 'food_1',
        'admin_uid': adminUid,
        'name': 'Margherita Pizza',
        'price': 12.99,
        'image_path': 'https://example.com/pizza.jpg',
        'description': 'Classic pizza with tomato and mozzarella',
        'food_code': 'P001',
        'department': 'Pizza',
        'stocks': 10,
        'is_hot': 1,
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
      },
      {
        'id': 'food_2',
        'admin_uid': adminUid,
        'name': 'Pepperoni Pizza',
        'price': 15.99,
        'image_path': 'https://example.com/pepperoni.jpg',
        'description': 'Pizza with pepperoni and cheese',
        'food_code': 'P002',
        'department': 'Pizza',
        'stocks': 8,
        'is_hot': 1,
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
      },
      {
        'id': 'food_3',
        'admin_uid': adminUid,
        'name': 'Coca Cola',
        'price': 2.99,
        'image_path': 'https://example.com/coke.jpg',
        'description': 'Refreshing cola drink',
        'food_code': 'B001',
        'department': 'Beverages',
        'stocks': 20,
        'is_hot': 0,
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
      },
    ];

    for (final item in testItems) {
      await db.insert('food_items', item);
    }
  }

  /// Insert test departments for testing
  static Future<void> insertTestDepartments(Database db, String adminUid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final testDepartments = [
      {
        'id': 'dept_1',
        'admin_uid': adminUid,
        'name': 'Pizza',
        'image_url': 'https://example.com/pizza_dept.jpg',
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
      },
      {
        'id': 'dept_2',
        'admin_uid': adminUid,
        'name': 'Beverages',
        'image_url': 'https://example.com/beverages_dept.jpg',
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
      },
    ];

    for (final dept in testDepartments) {
      await db.insert('departments', dept);
    }
  }

  /// Insert test bills for testing
  static Future<void> insertTestBills(Database db, String adminUid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final yesterday = now - (24 * 60 * 60 * 1000);
    
    final testBills = [
      {
        'id': 'bill_1',
        'admin_uid': adminUid,
        'customer_phone': '+1234567890',
        'items': '[{"name": "Margherita Pizza", "price": 12.99, "quantity": 2}]',
        'total_amount': 25.98,
        'bill_date': now,
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
      },
      {
        'id': 'bill_2',
        'admin_uid': adminUid,
        'customer_phone': '+0987654321',
        'items': '[{"name": "Pepperoni Pizza", "price": 15.99, "quantity": 1}, {"name": "Coca Cola", "price": 2.99, "quantity": 2}]',
        'total_amount': 21.97,
        'bill_date': yesterday,
        'created_at': yesterday,
        'updated_at': yesterday,
        'sync_status': 1,
      },
    ];

    for (final bill in testBills) {
      await db.insert('bills', bill);
    }
  }
}