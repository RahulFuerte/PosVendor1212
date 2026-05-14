import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/login/providers/login_provider.dart';
import 'package:pos/view/login/screens/auth_landing_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/customer/customer_orders_screen.dart';
import 'customer_profile.dart';
import 'rasturunt_menu.dart';
import 'package:pos/core/widgets/skeleton.dart';
import 'package:pos/data/models/order_model.dart';
import 'dart:async';
import 'help_support_screen.dart';
import 'about_app_screen.dart';
import 'package:pos/data/services/order_service.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final UserService _userService = UserService();
  String _userName = 'Customer';
  String _selectedCity = 'Rajkot';
  Position? _currentPosition;
  List<UserModel> _shops = [];
  List<UserModel> _filteredShops = [];
  bool _isLoading = true;
  String _userPhone = '';
  String _userId = '';
  final TextEditingController _searchCtrl = TextEditingController();
  int _currentIndex = 0;
  Timer? _orderTimer;
  List<OrderModel> _readyOrders = [];
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startOrderPolling();
  }

  @override
  void dispose() {
    _orderTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startOrderPolling() {
    _orderTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkReadyOrders();
    });
    // Initial check
    _checkReadyOrders();
  }

  Future<void> _checkReadyOrders() async {
    if (_userId.isEmpty) return;
    try {
      final orders = await _orderService.getOrders(
        status: 'Ready',
        unknownCustomerId: _userId,
      );
      if (mounted) {
        setState(() {
          _readyOrders = orders;
        });
      }
    } catch (e) {
      debugPrint('Error checking ready orders: $e');
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('name') ?? 'Customer';
        _userPhone = prefs.getString('phoneNumber') ?? '';
        _userId = prefs.getString('_id') ?? '';
      });

      await _fetchShopsByLocation(isInitial: true);
    } catch (e) {
      debugPrint('Error loading customer dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchShopsByLocation({bool isInitial = false}) async {
    if (!isInitial) setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();
      setState(() => _currentPosition = position);

      final shops = await _userService.getShopsByLocation(
        lat: position.latitude,
        lng: position.longitude,
      );

      setState(() {
        _shops = shops;
        _filteredShops = shops;
        _selectedCity = "Nearby";
      });
    } catch (e) {
      debugPrint('Location search failed: $e');
      if (!isInitial && mounted) {
        SnackBarUtils.showError(context, 'Location error: ${e.toString().split(':').last}');
      }
      final shops = await _userService.getShopsByCity(_selectedCity);
      setState(() {
        _shops = shops;
        _filteredShops = shops;
      });
    } finally {
      if (!isInitial && mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _filterShops(String query) {
    setState(() {
      _filteredShops = _shops
          .where((shop) =>
              (shop.shopName ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (shop.address ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (shop.city ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showCityPicker() {
    final cityCtrl = TextEditingController(text: _selectedCity == "Nearby" ? "" : _selectedCity);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const MyText(text: 'Service Location', fontSize: 22, fontWeight: FontWeight.bold),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _fetchShopsByLocation();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.my_location, color: primaryColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(text: 'Use Current Location', fontWeight: FontWeight.bold, fontSize: 15),
                            MyText(text: 'Using GPS to find nearby restaurants', color: Colors.grey, fontSize: 12),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const MyText(text: 'Or search by city', color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Rajkot, Ahmedabad',
                  prefixIcon: const Icon(Icons.location_city, color: primaryColor),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (cityCtrl.text.isNotEmpty) {
                      setState(() {
                        _selectedCity = cityCtrl.text.trim();
                        _currentPosition = null;
                      });
                      Navigator.pop(context);
                      _fetchShopsByCity(_selectedCity);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const MyText(text: 'Update Location', color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchShopsByCity(String city) async {
    setState(() => _isLoading = true);
    try {
      final shops = await _userService.getShopsByCity(city);
      setState(() {
        _shops = shops;
        _filteredShops = shops;
      });
    } catch (e) {
      debugPrint('City search failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 32),
              ),
              const SizedBox(height: 24),
              const MyText(text: 'Sign Out', fontWeight: FontWeight.bold, fontSize: 22),
              const SizedBox(height: 8),
              const MyText(
                text: 'Are you sure you want to sign out from your account?',
                color: Colors.grey,
                maxLines: 2,
                textAlign: TextAlign.center,
                fontSize: 14,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: MyText(text: 'Cancel', color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); // Close dialog
                        // 1. Clear database and prefs
                        await _userService.logout();

                        // 2. Reset all providers in memory to clear UI state
                        if (mounted) {
                          context.read<TableProvider>().clear();
                          context.read<PrintProvider>().reset();
                          context.read<SubscriptionProvider>().reset();
                          context.read<OrderTypeProvider>().reset();
                          context.read<LoginProvider>().reset();

                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const MyText(text: 'Sign Out', color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _showLogoutDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeView(),
            _buildSettingsView(),
          ],
        ),
        bottomNavigationBar: Container(
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded, color: primaryColor),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded),
                activeIcon: Icon(Icons.settings_rounded, color: primaryColor),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // NOTIFICATION BANNER
        if (_readyOrders.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildOrderNotification(),
          ),

        // PREMIUM HEADER
        SliverAppBar(
          expandedHeight: 180.0,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  // Subtle Accent decoration
                  Positioned(
                    right: -30,
                    top: -30,
                    child: CircleAvatar(
                      radius: 100,
                      backgroundColor: primaryColor.withOpacity(0.03),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: primaryColor, size: 16),
                                      const SizedBox(width: 4),
                                      MyText(
                                        text: 'DELIVERING TO',
                                        color: Colors.grey.shade400,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        fontFamily: 'Outfit',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: _showCityPicker,
                                    child: Row(
                                      children: [
                                        MyText(
                                          text: _selectedCity,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                          fontFamily: 'Outfit',
                                        ),
                                        const Icon(Icons.keyboard_arrow_down, color: primaryColor, size: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _HeaderActionIcon(Icons.logout_rounded, _showLogoutDialog, isDanger: true),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _searchBar(),
            ),
          ),
        ),

        // RESTAURANT LIST HEADER
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const MyText(
                  text: 'Popular Restaurants',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ],
            ),
          ),
        ),

        _isLoading
            ? SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _ShopSkeletonGrid(),
              )
            : _filteredShops.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const MyText(text: 'No restaurants in this area', fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _ShopGridCard(
                            shop: _filteredShops[index],
                            userPosition: _currentPosition,
                            userPhone: _userPhone,
                          );
                        },
                        childCount: _filteredShops.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                    ),
                  ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildOrderNotification() {
    final order = _readyOrders.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MyText(
                  text: 'Your order is READY!',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                MyText(
                  text: 'Order #${order.billNumber} is waiting for pickup',
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CustomerOrdersScreen(customerId: _userId)),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const MyText(
              text: 'View',
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView() {
    return CustomScrollView(
      slivers: [
        // PREMIUM SETTINGS HEADER
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  // Decorative Gradient Circle
                  Positioned(
                    right: -50,
                    top: -20,
                    child: CircleAvatar(
                      radius: 120,
                      backgroundColor: primaryColor.withOpacity(0.04),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: primaryColor.withOpacity(0.02),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: MyText(
                                  text: _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyText(
                                    text: _userName,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                  ),
                                  const SizedBox(height: 4),
                                  MyText(
                                    text: _userPhone,
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ],
                              ),
                            ),
                            _HeaderActionIcon(Icons.logout_rounded, _showLogoutDialog, isDanger: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MyText(
                  text: 'Account Settings',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                  fontFamily: 'Outfit',
                ),
                const SizedBox(height: 16),
                _buildSettingsCard([
                  _SettingsItemData(
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    subtitle: 'Personal details and credentials',
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerProfileScreen())),
                  ),
                  _SettingsItemData(
                    icon: Icons.history_rounded,
                    title: 'Order History',
                    subtitle: 'Your past orders and bills',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => CustomerOrdersScreen(customerId: _userId))),
                  ),
                ]),
                const SizedBox(height: 32),
                const MyText(
                  text: 'General Preferences',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                  fontFamily: 'Outfit',
                ),
                const SizedBox(height: 16),
                _buildSettingsCard([
                  _SettingsItemData(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Control notification alerts',
                    onTap: () {},
                  ),
                  _SettingsItemData(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and direct contact',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                  ),
                  _SettingsItemData(
                    icon: Icons.info_outline_rounded,
                    title: 'About App',
                    subtitle: 'Version and terms',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen())),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<_SettingsItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _buildSettingsItem(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                onTap: item.onTap,
              ),
              if (index < items.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 70),
                  child: Divider(height: 1, color: Colors.grey.shade100),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDanger ? Colors.red.shade50 : primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isDanger ? Colors.red.shade400 : primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: title,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDanger ? Colors.red.shade400 : Colors.black,
                  ),
                  const SizedBox(height: 2),
                  MyText(
                    text: subtitle,
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _HeaderActionIcon(IconData icon, VoidCallback onTap, {bool isDanger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDanger ? Colors.red.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDanger ? Colors.red.shade100 : Colors.grey.shade200),
        ),
        child: Icon(icon, color: isDanger ? Colors.red.shade400 : Colors.black87, size: 20),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) => _filterShops(value),
        style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
        decoration: InputDecoration(
          hintText: 'Search near by restaurants',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: primaryColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

class _ShopGridCard extends StatelessWidget {
  final UserModel shop;
  final Position? userPosition;
  final String userPhone;

  const _ShopGridCard({
    required this.shop,
    this.userPosition,
    required this.userPhone,
  });

  String _getDistance() {
    if (userPosition == null || shop.location?.latitude == null || shop.location?.longitude == null) return "";

    final distance = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      shop.location!.latitude!,
      shop.location!.longitude!,
    );

    double distKm = distance / 1000;
    if (distKm < 1) {
      return "${distance.toStringAsFixed(0)} m";
    }
    return "${distKm.toStringAsFixed(1)} km";
  }

  @override
  Widget build(BuildContext context) {
    final distance = _getDistance();
    final isOpen = shop.isShopOpen ?? true;

    return GestureDetector(
      onTap: () {
        if (!isOpen) {
          SnackBarUtils.showWarning(context, "${shop.shopName ?? 'Restaurant'} is currently closed. Please check back later!");
          return;
        }

        context.read<PrintProvider>().clearCart();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RasturuntMenu(
              adminId: shop.id ?? shop.phoneNumber ?? '',
              userPhone: userPhone,
              restaurantName: shop.shopName ?? '',
              restaurantImage: shop.logoUrl,
              restaurantLocation: shop.city,
            ),
          ),
        );
      },
      child: Opacity(
        opacity: isOpen ? 1.0 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// IMAGE SECTION
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: shop.logoUrl != null && shop.logoUrl!.isNotEmpty
                            ? Image.network(
                                shop.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.grey.shade100,
                                  child: const Icon(Icons.storefront, size: 40, color: Colors.grey),
                                ),
                              )
                            : Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.storefront, size: 40, color: Colors.grey),
                              ),
                      ),
                    ),
                    // Rating Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.orange),
                            const SizedBox(width: 2),
                            MyText(
                              text: "4.3",
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Outfit',
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Distance Badge
                    if (distance.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: MyText(
                            text: distance,
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              /// DETAILS SECTION
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: shop.shopName ?? 'Restaurant',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            fontFamily: 'Outfit',
                          ),
                          const SizedBox(height: 2),
                          MyText(
                            text: shop.city ?? 'Local Area',
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: MyText(
                              text: isOpen ? "OPEN" : "CLOSED",
                              fontSize: 9,
                              color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              MyText(
                                text: "25-30 min",
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopSkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Skeleton(borderRadius: 20),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 18, width: 100),
                        SizedBox(height: 8),
                        Skeleton(height: 14, width: 60),
                        Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Skeleton(height: 16, width: 40),
                            Skeleton(height: 16, width: 50),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        childCount: 6,
      ),
    );
  }
}

class _SettingsItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _SettingsItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
