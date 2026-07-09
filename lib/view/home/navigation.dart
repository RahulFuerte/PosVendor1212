import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/view/home/productDashBoard.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/data/providers/tour_provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/l10n/app_locale.dart';

import 'screens/calculator_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/table_management_screen.dart';

const Color appbar1 = Color.fromARGB(255, 12, 107, 15);

class Navigation extends StatefulWidget {
  final AnimationController? resizableController;
  final String uId;
  const Navigation({required this.uId, this.resizableController, super.key});

  @override
  State<Navigation> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<Navigation> {
  int currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  List<Widget> _pages = [];
  String businessCategory = 'Food';
  TutorialCoachMark? _tourMark;
  bool _tourShowing = false;
  TourProvider? _tourProvider;

  @override
  void initState() {
    super.initState();
    _loadBusinessCategory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndReloadTables();
      _checkTour();
    });
    _tourProvider = context.read<TourProvider>();
    _tourProvider!.addListener(_onTourStateChanged);
  }

  void _onTourStateChanged() {
    final tourProvider = context.read<TourProvider>();
    if (!tourProvider.isTourActive) return;
    final step = tourProvider.currentStep;
    if (step == 7) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && tourProvider.isTourActive && tourProvider.currentStep == 7) {
          if (currentIndex != 0) {
            setState(() { currentIndex = 0; });
          }
          _showTour();
        }
      });
    } else if (step == 17 && currentIndex != 1) {
      setState(() { currentIndex = 1; });
    } else if (step == 25 && currentIndex != 2) {
      setState(() { currentIndex = 2; });
    } else if (step == 27 && currentIndex != 3) {
      setState(() { currentIndex = 3; });
    } else if (step == 29 && currentIndex != 1) {
      setState(() { currentIndex = 1; });
    }
  }

  void _checkTour() {
    final tourProvider = context.read<TourProvider>();
    if (tourProvider.isTourActive && tourProvider.currentStep == 7) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showTour();
      });
    }
  }

  @override
  void dispose() {
    _tourProvider?.removeListener(_onTourStateChanged);
    _tourMark?.finish();
    super.dispose();
  }

  void _showTour() {
    if (_tourShowing) return;
    _tourShowing = true;
    final tourProvider = context.read<TourProvider>();
    final targets = [
      TargetFocus(
        identify: "nav_home",
        keyTarget: TourKeys.navHomeTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 7,
                title: AppLocale.tourTitle7.getString(context),
                description: AppLocale.tourDesc7.getString(context),
                onNext: () => controller.next(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "nav_billing",
        keyTarget: TourKeys.navBillingTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 8,
                title: AppLocale.tourTitle8.getString(context),
                description: AppLocale.tourDesc8.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "nav_tables",
        keyTarget: TourKeys.navTablesTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 9,
                title: AppLocale.tourTitle9.getString(context),
                description: AppLocale.tourDesc9.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "nav_calculator",
        keyTarget: TourKeys.navCalculatorTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return tourProvider.buildTourTooltip(
                context: context,
                step: 10,
                title: AppLocale.tourTitle10.getString(context),
                description: AppLocale.tourDesc10.getString(context),
                onNext: () => controller.next(),
                onPrev: () => controller.previous(),
                onSkip: () {
                  tourProvider.stopTour();
                  controller.skip();
                },
              );
            },
          ),
        ],
      ),
    ];

    final validTargets = targets.where((t) {
      final k = t.keyTarget;
      return k == null || k.currentContext != null;
    }).toList();
    if (validTargets.isEmpty) {
      _tourShowing = false;
      if (tourProvider.isTourActive) tourProvider.setStep(11);
      return;
    }

    _tourMark = TutorialCoachMark(
      targets: validTargets,
      hideSkip: true,
      colorShadow: Colors.black.withOpacity(0.85),
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        _tourShowing = false;
        if (tourProvider.isTourActive) {
          tourProvider.setStep(11);
        }
      },
      onSkip: () {
        _tourShowing = false;
        tourProvider.stopTour();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _loadBusinessCategory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        businessCategory = prefs.getString('businessCategory') ?? 'Food';
        _initNavigation();
      });
    }
  }

  Future<void> _checkAndReloadTables() async {
    // Reload tables to ensure we have the correct data for current user/demo mode
    final tableProvider = context.read<TableProvider>();
    await tableProvider.reloadTables();
  }

  @override
  void didUpdateWidget(Navigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uId != widget.uId) {
      _initNavigation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndReloadTables();
      });
    }
  }

  void _initNavigation() {
    // Determine tab count
    int count = businessCategory == 'Food' ? 4 : 3;

    // Setup keys
    _navigatorKeys.clear();
    for (int i = 0; i < count; i++) {
      _navigatorKeys.add(GlobalKey<NavigatorState>());
    }

    // Build cached pages
    _pages = _buildPages();

    // Reset index if it becomes invalid
    if (currentIndex >= count) {
      currentIndex = 0;
    }
  }

  List<Widget> _buildPages() {
    return [
      _buildNavigator(0, const ProductDashBoard()),
      _buildNavigator(1, const RestaurantScreen()),
      if (businessCategory == 'Food') _buildNavigator(2, const TableManagementScreen()),
      _buildNavigator(businessCategory == 'Food' ? 3 : 2, const PLUCalculatorScreen()),
    ];
  }

  List<IconData> _buildIcons() {
    return [
      Icons.grid_view_rounded,
      businessCategory == 'Food' ? Icons.restaurant : Icons.shopping_bag,
      if (businessCategory == 'Food') Icons.table_bar,
      Icons.calculate
    ];
  }

  Widget _buildNavigator(int index, Widget rootPage) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => rootPage);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final icons = _buildIcons();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final NavigatorState? currentNavigator = _navigatorKeys[currentIndex].currentState;

        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else if (currentIndex != 0) {
          setState(() => currentIndex = 0);
        } else {
          // If at the root of the first tab, check if parent can pop
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // Exit the app
            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          height: 65,
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade100,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: true,
            child: Row(
              children: List.generate(icons.length, (index) {
                Key? itemKey;
                if (index == 0) {
                  itemKey = TourKeys.navHomeTabKey;
                } else if (index == 1) {
                  itemKey = TourKeys.navBillingTabKey;
                } else if (index == 2 && businessCategory == 'Food') {
                  itemKey = TourKeys.navTablesTabKey;
                } else if (index == (businessCategory == 'Food' ? 3 : 2)) {
                  itemKey = TourKeys.navCalculatorTabKey;
                }

                return BottomNavItem(
                    key: itemKey,
                    index: index,
                    currentIndex: currentIndex,
                    icon: icons[index],
                    activeColor: appbar1,
                    onTap: () {
                      if (currentIndex == index) {
                        _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
                      } else {
                        // index 2 = TableManagementScreen (adjust if needed)
                        context.read<TableProvider>().clear();

                        setState(() {
                          currentIndex = index;
                        });
                      }
                    });
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final Color activeColor;
  final VoidCallback onTap;

  const BottomNavItem({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            /// Highlight Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              width: isActive ? 32 : 0,
              height: 5,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
            ),
            const Spacer(),

            /// Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                size: 24,
                color: isActive ? activeColor : Colors.grey.shade400,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
