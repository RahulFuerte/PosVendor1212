// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/data/providers/barcode_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localization/flutter_localization.dart';

// Project imports:
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:pos/data/datasources/database_service.dart';
import 'package:pos/data/datasources/online_database_service.dart';
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

  await FlutterLocalization.instance.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_language') ?? 'en';

  runApp(MyApp(initialLanguage: savedLang));
}

class MyApp extends StatefulWidget {
  final String initialLanguage;
  const MyApp({super.key, this.initialLanguage = 'en'});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterLocalization _localization = FlutterLocalization.instance;

  @override
  void initState() {
    super.initState();
    _localization.init(
      mapLocales: [
        const MapLocale('en', AppLocale.EN),
        const MapLocale('gu', AppLocale.GU),
        const MapLocale('hi', AppLocale.HI),
        const MapLocale('sd', AppLocale.SD),
        const MapLocale('mr', AppLocale.MR),
        const MapLocale('pa', AppLocale.PA),
        const MapLocale('bn', AppLocale.BN),
        const MapLocale('ta', AppLocale.TA),
        const MapLocale('te', AppLocale.TE),
        const MapLocale('ur', AppLocale.UR),
      ],
      initLanguageCode: widget.initialLanguage,
    );
    _localization.onTranslatedLanguage = _onTranslatedLanguage;
  }

  void _onTranslatedLanguage(Locale? locale) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // DatabaseService - Core data access layer with SQLite
        Provider<DatabaseService>(
          create: (_) {
            final service = OnlineDatabaseService();
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
        ChangeNotifierProvider(
          create: (context) => TableProvider(),
        ),
        ChangeNotifierProvider(create: (_) => BarcodeProvider()),
        ChangeNotifierProvider(create: (_) => TourProvider()),
      ],
      child: MaterialApp(
        title: 'Billing Sphere',
        supportedLocales: _localization.supportedLocales,
        localizationsDelegates: _localization.localizationsDelegates,
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
