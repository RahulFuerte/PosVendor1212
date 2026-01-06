// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/sync_manager.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SyncManager Basic Tests', () {
    late SyncManager syncManager;

    setUp(() {
      syncManager = SyncManager();
    });

    tearDown(() {
      syncManager.dispose();
    });

    test('should create sync manager instance', () {
      expect(syncManager, isNotNull);
      expect(syncManager.currentStatus, equals(SyncOperationStatus.idle));
    });

    test('should provide sync status stream', () {
      expect(syncManager.syncStatusStream, isA<Stream<SyncOperationStatus>>());
    });

    test('should provide sync result stream', () {
      expect(syncManager.syncResultStream, isA<Stream<SyncResult>>());
    });

    test('should handle sync cancellation', () {
      syncManager.cancelSync();
      expect(syncManager.currentStatus, equals(SyncOperationStatus.idle));
    });

    test('should return sync statistics without initialization', () async {
      final stats = await syncManager.getSyncStatistics();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('currentStatus'), true);
      expect(stats.containsKey('retryCount'), true);
      expect(stats.containsKey('isConnected'), true);
      expect(stats.containsKey('isInitialized'), true);
      expect(stats['isInitialized'], false);
    });

    test('should handle sync when not initialized', () async {
      // Test sync without initialization (should fail gracefully)
      final result = await syncManager.syncPendingData();
      expect(result.success, false);
      expect(result.errorMessage, contains('No internet connection'));
    });

    test('should get last sync time', () async {
      final lastSyncTime = await syncManager.getLastSyncTime();
      // Should return null initially since no sync has been performed
      expect(lastSyncTime, isNull);
    });

    test('should check initialization status', () {
      expect(syncManager.isInitialized, false);
    });
  });
}
