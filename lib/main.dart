// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/providers/admin_uid_provider.dart';
import 'package:pos/data/providers/order_type_provider.dart';

import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/unified_database_service.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/login/providers/login_provider.dart';
import 'package:pos/view/login/screens/splash_screen.dart';

//3.16.9
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('userBox');

  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // DatabaseService - Core data access layer with SQLite and Firebase sync
        // Must be initialized first as other services may depend on it
        // Provides offline-first data operations with automatic synchronization
        Provider<DatabaseService>(
          create: (_) {
            final service = UnifiedDatabaseService();
            // Initialize asynchronously - the service handles initialization gracefully
            service.initialize();
            return service;
          },
          dispose: (_, service) => service.close(),
        ),

        // Application state providers
        // These providers manage UI state and user session data
        ChangeNotifierProvider(
          create: (context) {
            LoginProvider lp = LoginProvider();
            lp.init(); // Initialize user session state
            return lp;
          },
        ),
        ChangeNotifierProvider(create: (_) => AdminUidProvider()),
        ChangeNotifierProvider(create: (_) => PrintProvider()),
        ChangeNotifierProvider(create: (_) => OrderTypeProvider()),
      ],
      child: const MaterialApp(
        title: 'POS',
        // theme: ThemeData(
        //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        //   useMaterial3: true,
        // ),
        home: SplashScreen(),
        // home: CustomerWiseReport(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
