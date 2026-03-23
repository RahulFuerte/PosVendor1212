// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

// Package imports:
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/unified_database_service.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/login/providers/login_provider.dart';
import 'package:pos/view/login/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('userBox');

  // Initialize Firebase for Image Uploads
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // We don't throw here to allow the app to run offline or without Firebase,
    // but features requiring Firebase will fail gracefully.
  }

  // Firebase initialization restored for Image Uploads
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // DatabaseService - Core data access layer with SQLite
        Provider<DatabaseService>(
          create: (_) {
            final service = UnifiedDatabaseService();
            service.initialize();
            return service;
          },
          dispose: (_, service) => service.close(),
        ),

        // Application state providers
        ChangeNotifierProvider(
          create: (context) {
            LoginProvider lp = LoginProvider();
            lp.init();
            return lp;
          },
        ),
        ChangeNotifierProvider(create: (_) => PrintProvider()),
        ChangeNotifierProvider(create: (_) => OrderTypeProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: const MaterialApp(
        title: 'POS',
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
