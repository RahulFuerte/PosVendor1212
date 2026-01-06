// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/widgets/responsive_grid_item.dart';

void main() {
  group('Overflow Prevention Tests', () {
    testWidgets('ResponsiveGridItem should not overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250, // Constrained height
              child: ResponsiveGridItem(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Colors.blue,
                        child: const Center(child: Text('Image')),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          const Text(
                            'Very long product name that might cause overflow',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Add to Cart'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('FlexibleGridColumn should handle varying content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: FlexibleGridColumn(
                children: [
                  Container(
                    height: 100,
                    color: Colors.red,
                    child: const Text('Fixed height'),
                  ),
                  const Text('Flexible text content'),
                  Container(
                    height: 50,
                    color: Colors.green,
                    child: const Text('Another fixed'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    test('GridLayoutHelper should calculate appropriate aspect ratios', () {
      // Test aspect ratio calculation
      final aspectRatio = GridLayoutHelper.calculateAspectRatio(
        imageHeightRatio: 0.6,
        contentHeightRatio: 0.4,
        padding: 16.0,
      );

      expect(aspectRatio, greaterThan(0.5));
      expect(aspectRatio, lessThan(1.5));
    });

    test('GridLayoutHelper should provide reasonable constants', () {
      expect(GridLayoutHelper.foodItemCard, equals(0.78));
      expect(GridLayoutHelper.productCard, equals(0.75));
      expect(GridLayoutHelper.simpleCard, equals(0.85));
      expect(GridLayoutHelper.tallCard, equals(0.65));
    });

    testWidgets('GridLayoutHelper should calculate cross axis count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final count = GridLayoutHelper.calculateCrossAxisCount(
                context,
                minItemWidth: 150.0,
                maxCount: 4,
                minCount: 1,
              );

              expect(count, greaterThanOrEqualTo(1));
              expect(count, lessThanOrEqualTo(4));

              return Container();
            },
          ),
        ),
      );
    });
  });
}
