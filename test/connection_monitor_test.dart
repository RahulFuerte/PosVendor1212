import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/connection_monitor.dart';

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