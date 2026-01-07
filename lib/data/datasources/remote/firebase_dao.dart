// Dart imports:
import 'dart:convert';
import 'dart:typed_data';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../database_service.dart';

/// Firebase Data Access Object for cloud database operations
class FirebaseDAO implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Helper method to parse timestamp from various formats
  int parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }

    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }

    if (timestamp is String) {
      try {
        // Try to parse as DateTime string
        final dateTime = DateTime.parse(timestamp);
        return dateTime.millisecondsSinceEpoch;
      } catch (e) {
        // If parsing fails, return current time
        return DateTime.now().millisecondsSinceEpoch;
      }
    }

    if (timestamp is int) {
      return timestamp;
    }

    // Fallback to current time
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Transform Firebase data to SQLite-compatible format
  Map<String, dynamic> transformFirebaseToSQLite(
    Map<String, dynamic> firebaseData,
    String docId, {
    bool? isFoodItem,
  }) {
    final transformed = <String, dynamic>{
      'id': docId,
      'firebase_id': docId,
      'sync_status': SyncStatus.synced.value,
    };

    // Map Firebase fields to SQLite fields
    final fieldMappings = {
      // Firebase field -> SQLite field..............
      'name': 'name',
      'price': 'price',
      'imagePath': 'image_path',
      'description': 'description',
      'foodCode': 'food_code',
      'department': 'department',
      'stocks': 'stocks',
      'isHot': 'is_hot',
      'tax': 'tax',
      'adminUid': 'admin_uid',
      'uid': 'admin_uid',
      'imageUrl': 'image_url',
      'status': 'status',
      'customerPhone': 'customer_phone',
      'items': 'items',
      'totalAmount': 'total_amount',
      'billDate': 'bill_date',
    };

    // Transform fields
    for (final entry in fieldMappings.entries) {
      final firebaseField = entry.key;
      final sqliteField = entry.value;

      if (firebaseData.containsKey(firebaseField)) {
        var value = firebaseData[firebaseField];

        // Handle special transformations
        if (sqliteField == 'is_hot' && value is bool) {
          value = value ? 1 : 0;
        } else if (sqliteField == 'bill_date' && value is Timestamp) {
          value = value.millisecondsSinceEpoch;
        }

        transformed[sqliteField] = value;
      }
    }

    final bool isFood = isFoodItem ?? false;

    if (isFood) {
      transformed['baseVariant'] = firebaseData['baseVariant'] ?? '';

      final variants = firebaseData['variants'];
      transformed['variants'] = jsonEncode(
        variants is List ? variants.map((v) => Map<String, dynamic>.from(v)).toList() : [],
      );
    }

    // Handle timestamps
    transformed['created_at'] = parseTimestamp(firebaseData['createdAt']);
    transformed['updated_at'] = parseTimestamp(firebaseData['updatedAt']);

    // Copy any remaining fields that don't need transformation
    for (final entry in firebaseData.entries) {
      final key = entry.key;
      if (!fieldMappings.containsKey(key) &&
          key != 'createdAt' &&
          key != 'updatedAt' &&
          !transformed.containsKey(key)) {
        transformed[key] = entry.value;
      }
    }

    return transformed;
  }

  /// Transform SQLite data to Firebase-compatible format
  Map<String, dynamic> transformSQLiteToFirebase(Map<String, dynamic> sqliteData) {
    final transformed = <String, dynamic>{};

    // Reverse field mappings (SQLite field -> Firebase field)
    final fieldMappings = {
      'name': 'name',
      'price': 'price',
      'image_path': 'imagePath',
      'description': 'description',
      'food_code': 'foodCode',
      'department': 'department',
      'stocks': 'stocks',
      'is_hot': 'isHot',
      'tax': 'tax',
      'image_url': 'imageUrl', // For departments
      'status': 'status',
      'customer_phone': 'customerPhone', // For bills
      'items': 'items',
      'total_amount': 'totalAmount',
      'bill_date': 'billDate',
    };

    // Transform fields
    for (final entry in fieldMappings.entries) {
      final sqliteField = entry.key;
      final firebaseField = entry.value;

      if (sqliteData.containsKey(sqliteField)) {
        var value = sqliteData[sqliteField];

        // Handle special transformations
        if (sqliteField == 'is_hot' && value is int) {
          value = value == 1;
        } else if (sqliteField == 'bill_date' && value is int) {
          value = Timestamp.fromMillisecondsSinceEpoch(value);
        }

        transformed[firebaseField] = value;
      }
    }

    // Copy any remaining fields that don't need transformation
    for (final entry in sqliteData.entries) {
      final key = entry.key;
      if (!fieldMappings.containsKey(key) &&
          key != 'admin_uid' &&
          key != 'created_at' &&
          key != 'updated_at' &&
          key != 'sync_status' &&
          key != 'firebase_id' &&
          key != 'image_blob' &&
          !transformed.containsKey(key)) {
        transformed[key] = entry.value;
      }
    }

    return transformed;
  }

  @override
  Future<void> initialize() async {
    // Firebase is initialized in main.dart
    // No additional initialization needed
  }

  @override
  Future<void> close() async {
    // Firebase connections are managed automatically
    // No explicit close needed
  }

  @override
  Future<bool> isOnline() async {
    try {
      // Try to perform a simple read operation to check connectivity
      await _firestore.collection('_health_check').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Food Items operations
  @override
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department}) async {
    try {
      Query query = _firestore.collection('AllAdmins').doc(adminUid).collection('foodItems');

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      final QuerySnapshot querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return transformFirebaseToSQLite(data, doc.id, isFoodItem: true);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch food items from Firebase: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getFoodItem(String adminUid, String itemId) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('AllAdmins').doc(adminUid).collection('foodItems').doc(itemId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return transformFirebaseToSQLite(data, doc.id, isFoodItem: true);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch food item from Firebase: $e');
    }
  }

  @override
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    try {
      final now = Timestamp.now();
      final Map<String, dynamic> firebaseData = transformSQLiteToFirebase(foodItem);

      // Add Firebase-specific timestamps
      firebaseData['createdAt'] = now;
      firebaseData['updatedAt'] = now;

      await _firestore
          .collection('AllAdmins')
          .doc(adminUid)
          .collection('foodItems')
          .doc(foodItem['id'])
          .set(firebaseData);
    } catch (e) {
      throw Exception('Failed to save food item to Firebase: $e');
    }
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, Map<String, dynamic> updates) async {
    try {
      final Map<String, dynamic> firebaseUpdates = transformSQLiteToFirebase(updates);

      // Add Firebase-specific timestamp
      firebaseUpdates['updatedAt'] = Timestamp.now();

      await _firestore
          .collection('AllAdmins')
          .doc(adminUid)
          .collection('foodItems')
          .doc(itemId)
          .update(firebaseUpdates);
    } catch (e) {
      throw Exception('Failed to update food item in Firebase: $e');
    }
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    try {
      await _firestore.collection('AllAdmins').doc(adminUid).collection('foodItems').doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete food item from Firebase: $e');
    }
  }

  // Departments operations
  @override
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('AllAdmins')
          .doc(adminUid)
          .collection('departments')
          .where('status', isEqualTo: 'Active')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return transformFirebaseToSQLite(data, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch departments from Firebase: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getDepartment(String adminUid, String departmentId) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('AllAdmins').doc(adminUid).collection('departments').doc(departmentId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return transformFirebaseToSQLite(data, doc.id);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch department from Firebase: $e');
    }
  }

  @override
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    try {
      final now = Timestamp.now();
      final Map<String, dynamic> firebaseData = transformSQLiteToFirebase(department);

      // Add Firebase-specific timestamps
      firebaseData['createdAt'] = now;
      firebaseData['updatedAt'] = now;

      await _firestore
          .collection('AllAdmins')
          .doc(adminUid)
          .collection('departments')
          .doc(department['id'])
          .set(firebaseData);
    } catch (e) {
      throw Exception('Failed to save department to Firebase: $e');
    }
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, Map<String, dynamic> updates) async {
    try {
      final Map<String, dynamic> firebaseUpdates = transformSQLiteToFirebase(updates);

      // Add Firebase-specific timestamp
      firebaseUpdates['updatedAt'] = Timestamp.now();

      await _firestore
          .collection('AllAdmins')
          .doc(adminUid)
          .collection('departments')
          .doc(departmentId)
          .update(firebaseUpdates);
    } catch (e) {
      throw Exception('Failed to update department in Firebase: $e');
    }
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    try {
      await _firestore.collection('AllAdmins').doc(adminUid).collection('departments').doc(departmentId).delete();
    } catch (e) {
      throw Exception('Failed to delete department from Firebase: $e');
    }
  }

  // Bills operations
  @override
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore.collection('AllBills').doc(adminUid).collection('myBills');

      if (startDate != null) {
        query = query.where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('billDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final QuerySnapshot querySnapshot = await query.orderBy('billDate', descending: true).get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return transformFirebaseToSQLite(data, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch bills from Firebase: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getBill(String adminUid, String billId) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('AllBills').doc(adminUid).collection('myBills').doc(billId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return transformFirebaseToSQLite(data, doc.id);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch bill from Firebase: $e');
    }
  }

  @override
  Future<void> saveBill(String adminUid, Map<String, dynamic> billData) async {
    try {
      final now = DateTime.now();
      final monthDoc = DateFormat('yyyyMM').format(now);
      final dateDoc = DateFormat('yyyyMMdd').format(now);

      // Parse items - convert from JSON string to array if needed
      List<Map<String, dynamic>> itemsArray = [];
      final itemsData = billData['items'];
      if (itemsData is String) {
        // Parse JSON string to array
        try {
          final decoded = jsonDecode(itemsData);
          if (decoded is List) {
            itemsArray = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (e) {
          // If parsing fails, use empty array
          itemsArray = [];
        }
      } else if (itemsData is List) {
        itemsArray = itemsData.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // Convert tax_enabled to boolean
      bool taxEnabled = false;
      final taxEnabledValue = billData['tax_enabled'];
      if (taxEnabledValue is bool) {
        taxEnabled = taxEnabledValue;
      } else if (taxEnabledValue is int) {
        taxEnabled = taxEnabledValue == 1;
      } else if (taxEnabledValue is String) {
        taxEnabled = taxEnabledValue == '1' || taxEnabledValue.toLowerCase() == 'true';
      }

      // Build Firebase data with proper types
      final Map<String, dynamic> firebaseData = {
        'adminId': adminUid,
        'receiptNo': billData['id'],
        'items': itemsArray, // Array, not string
        'subTotal': billData['sub_total'] ?? billData['total_amount'],
        'totalAmount': billData['total_amount'],
        'tableNumber': billData['table_number'] ?? 'N/A',
        'taxEnabled': taxEnabled, // Boolean, not int
        'cgstPercent': billData['cgst_percent'] ?? 0.0,
        'sgstPercent': billData['sgst_percent'] ?? 0.0,
        'cgstAmount': billData['cgst_amount'] ?? 0.0,
        'sgstAmount': billData['sgst_amount'] ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to: AllBills/{adminUid}/myBills/{monthDoc}/{dateDoc}/{receiptNo}
      await _firestore
          .collection('AllBills')
          .doc(adminUid)
          .collection('myBills')
          .doc(monthDoc)
          .collection(dateDoc)
          .doc(billData['id'])
          .set(firebaseData);
    } catch (e) {
      throw Exception('Failed to save bill to Firebase: $e');
    }
  }

  @override
  Future<void> updateBill(String adminUid, String billId, Map<String, dynamic> updates) async {
    try {
      final Map<String, dynamic> firebaseUpdates = transformSQLiteToFirebase(updates);

      // Add Firebase-specific timestamp
      firebaseUpdates['updatedAt'] = Timestamp.now();

      await _firestore.collection('AllBills').doc(adminUid).collection('myBills').doc(billId).update(firebaseUpdates);
    } catch (e) {
      throw Exception('Failed to update bill in Firebase: $e');
    }
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    try {
      await _firestore.collection('AllBills').doc(adminUid).collection('myBills').doc(billId).delete();
    } catch (e) {
      throw Exception('Failed to delete bill from Firebase: $e');
    }
  }

  // Sync operations (not applicable for Firebase DAO)
  @override
  Future<void> syncPendingData() async {
    throw UnimplementedError('Sync operations are not applicable for Firebase DAO');
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    throw UnimplementedError('Sync operations are not applicable for Firebase DAO');
  }

  @override
  Future<void> markAsSynced(String tableName, String recordId) async {
    throw UnimplementedError('Sync operations are not applicable for Firebase DAO');
  }

  @override
  Future<void> markAsPending(String tableName, String recordId) async {
    throw UnimplementedError('Sync operations are not applicable for Firebase DAO');
  }

  // Image operations
  @override
  Future<Uint8List?> getImageBlob(String tableName, String recordId) async {
    throw UnimplementedError('Image BLOB operations are handled by SQLite DAO');
  }

  @override
  Future<void> saveImageBlob(String tableName, String recordId, String imageUrl, Uint8List imageData) async {
    throw UnimplementedError('Image BLOB operations are handled by SQLite DAO');
  }

  @override
  Future<void> clearImageCache() async {
    throw UnimplementedError('Image cache operations are handled by SQLite DAO');
  }

  @override
  Future<Uint8List?> downloadAndCacheImage(String imageUrl, {String? tableName, String? recordId}) async {
    throw UnimplementedError('Image download and caching operations are handled by SQLite DAO and ImageCacheService');
  }

  // Firebase-specific image operations
  Future<String> uploadImage(String path, Uint8List imageData) async {
    try {
      final Reference ref = _storage.ref().child(path);
      final UploadTask uploadTask = ref.putData(imageData);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image to Firebase Storage: $e');
    }
  }

  Future<Uint8List?> downloadImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      return await ref.getData();
    } catch (e) {
      throw Exception('Failed to download image from Firebase Storage: $e');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        return {
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName,
          'phone': user.phoneNumber,
          'createdAt': user.metadata.creationTime?.toIso8601String(),
          'lastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }
}
