// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

// Package imports:
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/unified_database_service.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/data/providers/login_provider.dart';
import 'package:pos/view/login/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('userBox');

  // Initialize Firebase for Image Uploads
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Firebase initialization restored for Image Uploads
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.light,
  ));

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
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()..loadSavedSubscription()),
        ChangeNotifierProvider(
          create: (context) => TableProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Billing Sphere',
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black87),
            titleTextStyle: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        scaffoldMessengerKey: SnackBarUtils.messengerKey,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return ShowCaseWidget(
            onFinish: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_first_time_main_tutorial', false);
              // Don't set detailed tutorial here, let BillCartWidget handle it
              await prefs.setBool('is_first_time_drawer_tutorial', true); // Keep drawer separate
            },
            onComplete: (index, key) {
              // Individual step completion logic if needed
            },
            builder: (context) => child!,
          );
        },
      ),
    );
  }
}
