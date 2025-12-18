import 'package:pos/view/local_DB/customer_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CustomerDatabase {
  static final CustomerDatabase instance = CustomerDatabase._init();
  static Database? _database;

  CustomerDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('customers.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        gstNo TEXT,
        createdAt TEXT NOT NULL,
        isUploaded INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<CustomerModel> insertCustomer(CustomerModel customer) async {
    final db = await instance.database;
    final id = await db.insert('customers', customer.toMap());
    return customer.copyWith(id: id);
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final db = await instance.database;
    final result = await db.query(
      'customers',
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => CustomerModel.fromMap(map)).toList();
  }

  Future<List<CustomerModel>> getNotUploadedCustomers() async {
    final db = await instance.database;
    final result = await db.query(
      'customers',
      where: 'isUploaded = ?',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => CustomerModel.fromMap(map)).toList();
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await instance.database;
    return db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAsUploaded(int id) async {
    final db = await instance.database;
    return db.update(
      'customers',
      {'isUploaded': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
