// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/network/connection_monitor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:


void main() {
  // Initialize Flutter binding and sqflite for testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ConnectionMonitor Tests', () {
    late ConnectionMonitor connectionMonitor;

    setUp(() {
      connectionMonitor = ConnectionMonitor();
    });

    tearDown(() {
      connectionMonitor.dispose();
    });

    test('should initialize successfully', () async {
      await connectionMonitor.initialize();
      expect(connectionMonitor.isConnected, isA<bool>());
    });

    test('should provide connectivity stream', () async {
      await connectionMonitor.initialize();
      expect(connectionMonitor.connectivityStream, isA<Stream<bool>>());
    });

    test('should check connectivity manually', () async {
      await connectionMonitor.initialize();
      final isConnected = await connectionMonitor.checkConnectivity();
      expect(isConnected, isA<bool>());
    });
  });
}
