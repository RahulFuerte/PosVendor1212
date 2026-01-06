// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'test_database_helper.dart';

void main() {
  group('SQLiteHelper Tests', () {

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      await TestDatabaseHelper.getTestDatabase();
    });

    tearDown(() async {
      await TestDatabaseHelper.closeTestDatabase();
    });

    test('should initialize database successfully', () async {
      // Test database initialization
      final db = await TestDatabaseHelper.getTestDatabase();
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('should create all required tables', () async {
      final db = await TestDatabaseHelper.getTestDatabase();
      
      // Check if all tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      
      final tableNames = tables.map((table) => table['name']).toList();
      
      expect(tableNames, contains('food_items'));
      expect(tableNames, contains('departments'));
      expect(tableNames, contains('bills'));
      expect(tableNames, contains('sync_log'));
      expect(tableNames, contains('image_cache'));
    });
  });
}
