import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ReportSkeleton extends StatelessWidget {
  final double height;
  final int itemCount;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const ReportSkeleton({
    super.key,
    this.height = 100,
    this.itemCount = 5,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }
}
