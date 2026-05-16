import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/view/home/productDashBoard.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/data/services/demo_data.dart';

import 'screens/calculator_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/table_management_screen.dart';

const Color appbar1 = Color.fromARGB(255, 12, 107, 15);

class Navigation extends StatefulWidget {
  final AnimationController? resizableController;
  final String uId;
  Navigation({required this.uId, this.resizableController, super.key});

  @override
  State<Navigation> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<Navigation> {
  int currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  List<Widget> _pages = [];
  String businessCategory = 'Food';

  @override
  void initState() {
    super.initState();
    _loadBusinessCategory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndReloadTables();
    });
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

  /// Check if tutorial should start when switching to restaurant screen
  Future<void> _checkAndStartTutorial(int newIndex) async {
    // Only start tutorial when switching to restaurant screen (index 1)
    if (newIndex == 1) {
      final prefs = await SharedPreferences.getInstance();
      final bool isDemoMode = prefs.getBool('isDemoMode') ?? false;
      final bool isMainFirstTime = prefs.getBool('is_first_time_main_tutorial') ?? true;

      if (isDemoMode && isMainFirstTime) {
        // Mark main tutorial as completed immediately so detailed tutorial can start
        await prefs.setBool('is_first_time_main_tutorial', false);

        // Delay to ensure the screen is fully loaded
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            final showcase = ShowCaseWidget.of(context);
            if (showcase != null) {
              showcase.startShowCase([
                TourKeys.drawerIconKey,
                TourKeys.tableSelectorKey,
                TourKeys.categoryListKey,
                TourKeys.firstProductKey,
              ]);
            }
          }
        });
      }
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
                return BottomNavItem(
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

                        // Check if tutorial should start for the new tab
                        _checkAndStartTutorial(index);
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
