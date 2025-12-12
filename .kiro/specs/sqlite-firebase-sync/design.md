# Design Document

## Overview

This design implements a robust local SQLite database system with Firebase synchronization for the POS application. The solution provides offline capability, improved performance, and data consistency across devices while maintaining backward compatibility with existing code.

## Architecture

The system follows an enhanced layered architecture pattern with performance optimization and intelligent sync management:

```
┌─────────────────────────────────────────┐
│              UI Layer                   │
│    (Existing Screens & Widgets)        │
│         + Sync Status UI                │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│           Service Layer                 │
│  (Database Service & Sync Manager)     │
│    + Performance Monitor                │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│          Data Access Layer              │
│    (SQLite DAO & Firebase DAO)         │
│  + Connection Monitor + Error Handler   │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│           Storage Layer                 │
│  (SQLite DB + Image Cache + Firebase)  │
│     + Data Integrity Service           │
└─────────────────────────────────────────┘
```

### Enhanced Key Components:

1. **Unified Database Service**: Main interface providing seamless offline-first data operations
2. **Intelligent Sync Manager**: Advanced synchronization with conflict resolution, retry logic, and performance optimization
3. **SQLite DAO**: High-performance local database operations with ACID compliance
4. **Firebase DAO**: Cloud operations with intelligent batching and error handling
5. **Connection Monitor**: Real-time network monitoring with adaptive sync triggering
6. **Image Cache Service**: Optimized BLOB storage with automatic cleanup and performance monitoring
7. **Performance Monitor**: Real-time performance tracking and optimization for database and sync operations
8. **Data Integrity Service**: Comprehensive data validation, corruption detection, and automatic recovery
9. **Error Handling Service**: Structured error management with user-friendly notifications and recovery workflows

## Components and Interfaces

### DatabaseService Interface
```dart
abstract class DatabaseService {
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid);
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid);
  Future<void> saveBill(Map<String, dynamic> billData);
  Future<List<Map<String, dynamic>>> getBills(String adminUid);
  Future<void> syncPendingData();
}
```

### SyncManager
```dart
class SyncManager {
  Future<void> syncToFirebase();
  Future<void> syncFromFirebase();
  Stream<SyncStatus> get syncStatusStream;
  Future<void> handleConflictResolution();
}
```

### SQLiteHelper
```dart
class SQLiteHelper {
  Future<Database> get database;
  Future<void> createTables();
  Future<void> migrateTables(int oldVersion, int newVersion);
}
```

### ImageCacheService
```dart
class ImageCacheService {
  Future<Uint8List?> downloadAndCacheImage(String imageUrl);
  Future<void> storeImageBlob(String itemId, Uint8List imageData);
  Future<Uint8List?> getImageBlob(String itemId);
  Future<void> clearImageCache();
}
```

## Data Models

### Image Storage Strategy

The system uses a hybrid approach for image storage:

1. **Firebase URLs**: Stored as TEXT for reference and sync purposes
2. **BLOB Storage**: Local image data cached for offline access
3. **Lazy Loading**: Images downloaded and cached on first access
4. **Cache Management**: Automatic cleanup of unused image BLOBs

#### Image Sync Workflow:
```
1. Download image from Firebase URL
2. Convert to Uint8List (bytes)
3. Store as BLOB in SQLite
4. Display from BLOB when offline
5. Sync new images to Firebase Storage when online
```

### Core Tables Schema

#### food_items
```sql
CREATE TABLE food_items (
  id TEXT PRIMARY KEY,
  admin_uid TEXT NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  image_path TEXT, -- Firebase URL for reference
  image_blob BLOB, -- Local image data for offline access
  description TEXT,
  food_code TEXT,
  department TEXT,
  stocks INTEGER,
  is_hot BOOLEAN DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status INTEGER DEFAULT 0, -- 0: synced, 1: pending, 2: conflict
  firebase_id TEXT
);
```

#### departments
```sql
CREATE TABLE departments (
  id TEXT PRIMARY KEY,
  admin_uid TEXT NOT NULL,
  name TEXT NOT NULL,
  image_url TEXT, -- Firebase URL for reference
  image_blob BLOB, -- Local image data for offline access
  status TEXT DEFAULT 'Active',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status INTEGER DEFAULT 0,
  firebase_id TEXT
);
```

#### bills
```sql
CREATE TABLE bills (
  id TEXT PRIMARY KEY,
  admin_uid TEXT NOT NULL,
  customer_phone TEXT,
  items TEXT NOT NULL, -- JSON string of bill items
  total_amount REAL NOT NULL,
  bill_date INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status INTEGER DEFAULT 0,
  firebase_id TEXT
);
```

#### sync_log
```sql
CREATE TABLE sync_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  operation TEXT NOT NULL, -- INSERT, UPDATE, DELETE
  sync_status INTEGER DEFAULT 0,
  error_message TEXT,
  created_at INTEGER NOT NULL,
  synced_at INTEGER
);
```

#### image_cache
```sql
CREATE TABLE image_cache (
  id TEXT PRIMARY KEY,
  table_name TEXT NOT NULL, -- food_items, departments
  record_id TEXT NOT NULL,
  image_url TEXT NOT NULL,
  image_blob BLOB,
  file_size INTEGER,
  cached_at INTEGER NOT NULL,
  last_accessed INTEGER NOT NULL,
  FOREIGN KEY (record_id) REFERENCES food_items(id) ON DELETE CASCADE
);
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

**Property 1: Database initialization consistency**
*For any* application startup, initializing the SQLite database should create all required tables with correct schema
**Validates: Requirements 1.1**

**Property 2: Immediate local data persistence**
*For any* data operation (create, update, delete), the data should be stored in SQLite immediately without delay
**Validates: Requirements 1.2**

**Property 3: Offline CRUD operations functionality**
*For any* CRUD operation performed while offline, the SQLite database should handle the operation successfully
**Validates: Requirements 1.3**

**Property 4: Sync status marking consistency**
*For any* local data modification, the record should be marked with appropriate sync status indicators
**Validates: Requirements 1.4**

**Property 5: Database query performance compliance**
*For any* standard database query operation, the SQLite database should return results within 100 milliseconds
**Validates: Requirements 1.5**

**Property 6: Automatic sync on connectivity**
*For any* pending local changes, when internet connectivity becomes available, the sync manager should automatically sync all changes to Firebase
**Validates: Requirements 2.1**

**Property 7: Bidirectional sync consistency**
*For any* Firebase data update, the sync manager should pull changes and update the corresponding local SQLite records
**Validates: Requirements 2.2**

**Property 8: Conflict resolution by timestamp**
*For any* data conflict during sync, the sync manager should resolve conflicts using timestamp-based priority (most recent wins)
**Validates: Requirements 2.3**

**Property 9: Sync status updates after completion**
*For any* completed sync operation, the sync manager should update the sync status indicators in the local database
**Validates: Requirements 2.4**

**Property 10: Exponential backoff retry pattern**
*For any* failed sync operation, the sync manager should retry with exponential backoff up to 3 attempts
**Validates: Requirements 2.5**

**Property 11: Interface compatibility preservation**
*For any* existing Firebase operation interface, the SQLite database should provide identical interfaces
**Validates: Requirements 3.1**

**Property 12: Backward compatibility preservation**
*For any* existing data operation call, the new SQLite database layer should handle the request without breaking existing functionality
**Validates: Requirements 3.2**

**Property 13: API consistency maintenance**
*For any* new database operation, the SQLite database should provide consistent API patterns
**Validates: Requirements 3.3**

**Property 14: Automatic database migration**
*For any* required schema update, the SQLite database should handle migrations automatically without data loss
**Validates: Requirements 3.4**

**Property 15: Error handling with fallbacks**
*For any* database error, the SQLite database should provide meaningful error messages and fallback mechanisms
**Validates: Requirements 3.5**

**Property 16: Sync progress UI indicators**
*For any* ongoing sync operation, the sync manager should display appropriate status indicators in the UI
**Validates: Requirements 4.1**

**Property 17: Sync completion confirmation**
*For any* successfully completed sync operation, the sync manager should show confirmation with timestamp
**Validates: Requirements 4.2**

**Property 18: Sync failure error display**
*For any* failed sync operation, the sync manager should display error messages with retry options
**Validates: Requirements 4.3**

**Property 19: Offline status indication**
*For any* offline mode operation, the sync manager should clearly indicate offline status in the UI
**Validates: Requirements 4.4**

**Property 20: Pending sync count display**
*For any* state with unsynchronized records, the sync manager should show the count of pending items
**Validates: Requirements 4.5**

**Property 21: Offline bill storage with pending status**
*For any* bill generated while offline, the SQLite database should store complete bill data with pending sync status
**Validates: Requirements 5.1**

**Property 22: Automatic offline bill sync on connectivity**
*For any* connectivity restoration, the sync manager should automatically detect and sync all pending offline bills
**Validates: Requirements 5.2**

**Property 23: Manual sync functionality**
*For any* manual sync trigger, the sync manager should immediately upload all pending offline data
**Validates: Requirements 5.3**

**Property 24: Bill status updates after sync**
*For any* successfully synced offline bill, the sync manager should update the bill status from pending to synced
**Validates: Requirements 5.4**

**Property 25: Failed bill sync retention**
*For any* failed offline bill sync, the sync manager should retain bills in pending status and retry on next connectivity check
**Validates: Requirements 5.5**

**Property 26: ACID transaction compliance**
*For any* SQLite write operation, the database should ensure ACID compliance for all transactions
**Validates: Requirements 6.1**

**Property 27: Data integrity validation during sync**
*For any* sync operation, the sync manager should validate data integrity before and after the sync process
**Validates: Requirements 6.2**

**Property 28: Automatic corruption recovery**
*For any* detected data corruption, the SQLite database should attempt automatic recovery from Firebase backup
**Validates: Requirements 6.3**

**Property 29: Backup creation before major sync**
*For any* major sync operation, the sync manager should create local database backups beforehand
**Validates: Requirements 6.4**

**Property 30: Data restoration mechanisms**
*For any* data restoration need, the SQLite database should provide mechanisms to restore from Firebase or local backups
**Validates: Requirements 6.5**

**Property 31: Image download performance compliance**
*For any* standard resolution image first accessed, the Image_Cache should download and store it locally within 2 seconds
**Validates: Requirements 7.1**

**Property 32: Cached image load performance**
*For any* cached image display request, the Image_Cache should load images from local storage within 100 milliseconds
**Validates: Requirements 7.2**

**Property 33: Database query performance optimization**
*For any* standard database query, the SQLite_Database should return results within 50 milliseconds
**Validates: Requirements 7.3**

**Property 34: UI responsiveness during sync**
*For any* sync operation running in background, the Performance_Monitor should ensure UI responsiveness is maintained
**Validates: Requirements 7.4**

**Property 35: Automatic image cache optimization**
*For any* unused images older than 30 days, the Image_Cache should automatically remove them to optimize storage
**Validates: Requirements 7.5**

**Property 36: Sync prioritization under bandwidth constraints**
*For any* limited network bandwidth condition, the Sync_Manager should prioritize critical business data over non-essential data
**Validates: Requirements 8.1**

**Property 37: Intelligent retry with enhanced backoff**
*For any* sync operation failing due to network issues, the Sync_Manager should implement intelligent retry with exponential backoff up to 5 attempts
**Validates: Requirements 8.2**

**Property 38: Efficient batch operation management**
*For any* multiple pending sync operations, the Sync_Manager should batch operations efficiently to minimize network overhead
**Validates: Requirements 8.3**

**Property 39: Adaptive sync behavior**
*For any* slow network condition detected, the Sync_Manager should adjust sync frequency and batch sizes automatically
**Validates: Requirements 8.4**

**Property 40: Conflict management and alerting**
*For any* frequent sync conflicts, the Sync_Manager should alert administrators and provide conflict resolution tools
**Validates: Requirements 8.5**

## Error Handling

### Error Categories:
1. **Network Errors**: Connection timeouts, no internet connectivity
2. **Database Errors**: SQLite corruption, constraint violations, disk space
3. **Sync Conflicts**: Concurrent modifications, version mismatches
4. **Firebase Errors**: Authentication failures, permission denied, quota exceeded

### Error Handling Strategy:
- **Graceful Degradation**: Continue offline operations when sync fails
- **User Feedback**: Clear error messages with actionable solutions
- **Automatic Recovery**: Retry mechanisms with exponential backoff
- **Data Integrity**: Rollback on critical failures

## Testing Strategy

### Unit Testing Approach:
- Test individual DAO operations for correctness
- Mock Firebase and SQLite for isolated testing
- Verify error handling and edge cases
- Test database migration scenarios

### Property-Based Testing Approach:
- Use **sqflite_test** for Flutter SQLite testing
- Configure each property-based test to run a minimum of 100 iterations
- Generate random data for comprehensive testing scenarios
- Test concurrent operations and race conditions

**Property-based testing requirements**:
- Each correctness property will be implemented by a SINGLE property-based test
- Each test will be tagged with the format: '**Feature: sqlite-firebase-sync, Property {number}: {property_text}**'
- Tests will verify universal properties across all valid inputs
- Complement unit tests by covering broader input spaces

### Integration Testing:
- Test complete sync workflows end-to-end
- Verify offline-to-online transitions
- Test conflict resolution scenarios
- Validate UI sync status indicators

### Performance Testing:
- Measure query response times under load
- Test sync performance with large datasets
- Verify memory usage during sync operations
- Test database performance on low-end devices