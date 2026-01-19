import 'package:flutter/material.dart';
import 'package:pos/view/home/productDashBoard.dart';

import 'screens/calculator_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/search_receipt_screen.dart';

Color appbar1 = const Color.fromARGB(255, 12, 107, 15);

// ignore: must_be_immutable
class Navigation extends StatefulWidget {
  late AnimationController resizableController;
  final String uId;
  Navigation({required this.uId, super.key});

  @override
  State<Navigation> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<Navigation> {
  int currentIndex = 0;
  List<Widget> pageview = [];

  @override
  void initState() {
    super.initState();
    pageview = [
      ProductDashBoard(phoneNo: widget.uId),
      RestaurantScreen(phoneNo: widget.uId),
      PLUCalculatorScreen(
        phoneNumber: widget.uId,
      ),
      // SearchReceiptScreen(phoneNumber: widget.uId)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pageview[currentIndex],
      bottomNavigationBar: SizedBox(
          height: 50,
          child: Row(
            children: List.generate(listOfIcons.length, (index) {
              return BottomNavItem(
                index: index,
                currentIndex: currentIndex,
                icon: listOfIcons[index],
                activeColor: appbar1,
                onTap: () {
                  setState(() {
                    currentIndex = index;
                  });
                },
              );
            }),
          )),
    );
  }

  List<IconData> listOfIcons = [
    Icons.local_fire_department,
    Icons.restaurant,
    Icons.calculate,
  ];
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
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.bounceOut,
              width: isActive ? 25 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: isActive ? activeColor : Colors.black,
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
