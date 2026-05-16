import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/login/login.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _bgAnimationController;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "image": "assets/images/logo-green.png",
      "title": "Welcome to\nBilling Sphere",
      "subtitle": "Simplify billing, manage inventory, and grow your business with an all-in-one POS solution.",
      "button": "Get Started",
    },
    {
      "image": "assets/images/razorpay.png",
      "title": "UPI & Card\nPayments Made Easy",
      "subtitle": "Accept secure payments with Razorpay. Fast transactions with automatic reconciliation.",
      "button": "Continue",
    },
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.2, 1.0, curve: Curves.easeIn)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _bgAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_app_first_launch_onboarding', false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const Login(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Dynamic Background Decorations
          _buildBackground(),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _contentController.forward(from: 0);
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], index);
                    },
                  ),
                ),
                _buildBottomSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Transform.rotate(
                angle: _bgAnimationController.value * 2 * math.pi,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.08),
                        primaryColor.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -150,
              child: Transform.rotate(
                angle: -_bgAnimationController.value * 2 * math.pi,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.05),
                        primaryColor.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const MyText(
              text: "Skip",
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> page, int index) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium Illustration Container
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.8, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  height: size.height * 0.35,
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      page['image']!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 60),
          // Content Area
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  MyText(
                    text: page['title']!,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    textAlign: TextAlign.center,
                    color: const Color(0xFF1A1A1A),
                    height: 1.1,
                    fontFamily: 'Outfit',
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: MyText(
                      text: page['subtitle']!,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                      color: Colors.black54,
                      height: 1.6,
                      maxLines: 4,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 50),
      child: Column(
        children: [
          // Animated Page Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 32 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? primaryColor : primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Action Button
          GestureDetector(
            onTap: () {
              if (!isLastPage) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutQuart,
                );
              } else {
                _completeOnboarding();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: MyText(
                  text: isLastPage ? "GET STARTED" : "CONTINUE",
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}