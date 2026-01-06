// Flutter imports:
import 'package:flutter/material.dart';

/// A responsive grid item widget that prevents overflow issues
/// by using flexible layouts and proper constraints
class ResponsiveGridItem extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BoxDecoration? decoration;
  final double? minHeight;
  final double? maxHeight;

  const ResponsiveGridItem({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.minHeight,
    this.maxHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: decoration,
      constraints: BoxConstraints(
        minHeight: minHeight ?? 0,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

/// A flexible column that prevents overflow in grid items
class FlexibleGridColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const FlexibleGridColumn({
    Key? key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children.map((child) {
        // Wrap non-Expanded widgets in Flexible to prevent overflow
        if (child is Expanded || child is Flexible) {
          return child;
        }
        return Flexible(child: child);
      }).toList(),
    );
  }
}

/// Grid layout helper that calculates optimal aspect ratios
class GridLayoutHelper {
  /// Calculates optimal aspect ratio based on content requirements
  static double calculateAspectRatio({
    required double imageHeightRatio,
    required double contentHeightRatio,
    double padding = 16.0,
  }) {
    // Total height = image + content + padding
    final totalHeightRatio = imageHeightRatio + contentHeightRatio + (padding / 100);
    
    // Aspect ratio = width / height
    // For a square-ish layout, we want width ≈ height
    return 1.0 / totalHeightRatio;
  }

  /// Provides common aspect ratios for different content types
  static const double foodItemCard = 0.78; // Good for image + title + button
  static const double productCard = 0.75;  // Good for image + title + price
  static const double simpleCard = 0.85;   // Good for minimal content
  static const double tallCard = 0.65;     // Good for lots of content

  /// Calculates cross axis count based on screen width
  static int calculateCrossAxisCount(BuildContext context, {
    double minItemWidth = 150.0,
    int maxCount = 4,
    int minCount = 1,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // Account for padding
    
    int count = (availableWidth / minItemWidth).floor();
    return count.clamp(minCount, maxCount);
  }
}

/// Example usage widget showing how to create overflow-safe grid items
class OverflowSafeGridExample extends StatelessWidget {
  const OverflowSafeGridExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overflow-Safe Grid Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: GridLayoutHelper.calculateCrossAxisCount(context),
            childAspectRatio: GridLayoutHelper.foodItemCard,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 20,
          itemBuilder: (context, index) {
            return ResponsiveGridItem(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FlexibleGridColumn(
                children: [
                  // Image section - takes available space
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.image, size: 40),
                    ),
                  ),
                  
                  // Content section - flexible height
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Item ${index + 1}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Add to Cart',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
