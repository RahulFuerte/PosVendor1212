import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class Mycarousel extends StatefulWidget {
  const Mycarousel({Key? key}) : super(key: key);

  @override
  State<Mycarousel> createState() => _MyCrausalState();
}

class _MyCrausalState extends State<Mycarousel> {
  int activeIndex = 0;
  final assetImages = [
    '$imagesPath/image1.jpg',
    '$imagesPath/image2.jpg',
    '$imagesPath/image3.jpg',
    '$imagesPath/image4.jpg',
  ];

  Widget buildImage(String assetImagePath, int index) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: grey,
        child: Image.asset(
          assetImagePath,
          fit: BoxFit.cover,
        ),
      );

  Widget buildIndicator() => AnimatedSmoothIndicator(
        activeIndex: activeIndex,
        count: assetImages.length,
        effect: const ScrollingDotsEffect(
            activeDotScale: 1.8,
            dotHeight: 5,
            dotWidth: 5,
            activeDotColor: primaryColor),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: assetImages.length,
          options: CarouselOptions(
            onPageChanged: (index, reason) {
              setState(() {
                activeIndex = index;
              });
            },
            viewportFraction: 1,
            height: 170,
            autoPlay: true,
          ),
          itemBuilder: (context, index, realIndex) {
            final assetImagePath = assetImages[index];
            return buildImage(assetImagePath, index);
          },
        ),
        const SizedBox(
          height: 4,
        ),
        buildIndicator(),
      ],
    );
  }
}
