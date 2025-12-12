import 'package:flutter/material.dart';
import 'package:pos/view/home/productDashBoard.dart';
import 'package:pos/view/home/calculator_screen.dart';
import 'package:pos/view/home/search_ReceiptScreen.dart';
import 'package:pos/view/home/restaurant_screen.dart';

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
      SearchReceiptScreen(phoneNumber: widget.uId)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pageview[currentIndex],
      bottomNavigationBar: SizedBox(
        height: 55,
        width: 20,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(
                () {
                  currentIndex = 0;
                },
              );
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.bounceOut,
                    width: currentIndex == 0 ? 25 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                        color: appbar1,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  Icon(
                    listOfIcons[0],
                    size: 22,
                    color: currentIndex == 0 ? appbar1 : Colors.black,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ]),
          )),
          Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(
                () {
                  currentIndex = 1;
                },
              );
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.bounceOut,
                    width: currentIndex == 1 ? 25 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                        color: appbar1,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  Icon(
                    listOfIcons[1],
                    size: 22,
                    color: currentIndex == 1 ? appbar1 : Colors.black,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ]),
          )),
          Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(
                () {
                  currentIndex = 2;
                },
              );
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.bounceOut,
                    width: currentIndex == 2 ? 25 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                        color: appbar1,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  Icon(
                    listOfIcons[2],
                    size: 22,
                    color: currentIndex == 2 ? appbar1 : Colors.black,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ]),
          )),
          Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(
                () {
                  currentIndex = 3;
                },
              );
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.bounceOut,
                    width: currentIndex == 3 ? 25 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                        color: appbar1,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  Icon(
                    listOfIcons[3],
                    size: 22,
                    color: currentIndex == 3 ? appbar1 : Colors.black,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ]),
          ))
        ]),
      ),
    );
  }

  List<IconData> listOfIcons = [
    
    Icons.local_fire_department,
    Icons.restaurant,
    Icons.calculate,
    Icons.search,
  ];
}
