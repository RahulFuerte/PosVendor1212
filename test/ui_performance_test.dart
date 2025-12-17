import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/view/tab_screen/view-model/widgets/ui_performance_components.dart';
import 'package:pos/view/tab_screen/view-model/widgets/enhanced_loading_states.dart';

void main() {
  group('UI Performance Components Tests', () {
    testWidgets('FoodItemSkeleton renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodItemSkeleton(),
          ),
        ),
      );

      expect(find.byType(FoodItemSkeleton), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('DepartmentSkeleton renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DepartmentSkeleton(),
          ),
        ),
      );

      expect(find.byType(DepartmentSkeleton), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('SmoothLoadingState renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothLoadingState(message: 'Test Loading'),
          ),
        ),
      );

      expect(find.byType(SmoothLoadingState), findsOneWidget);
      expect(find.text('Test Loading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('EnhancedEmptyState renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnhancedEmptyState(
              message: 'No items found',
              description: 'Try again later',
            ),
          ),
        ),
      );

      expect(find.byType(EnhancedEmptyState), findsOneWidget);
      expect(find.text('No items found'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
    });

    testWidgets('EnhancedErrorState renders correctly', (WidgetTester tester) async {
      bool retryPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedErrorState(
              message: 'Error occurred',
              description: 'Something went wrong',
              onRetry: () {
                retryPressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(EnhancedErrorState), findsOneWidget);
      expect(find.text('Error occurred'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Test retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();
      
      expect(retryPressed, isTrue);
    });

    testWidgets('GridLayoutHelper calculates correct cross axis count', (WidgetTester tester) async {
      // Test with actual MediaQuery context
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test different screen widths using MediaQuery.of(context).size.width
              final mediaQuery = MediaQuery.of(context);
              
              // Create a custom MediaQuery with different screen widths
              Widget testWidget(double width) {
                return MediaQuery(
                  data: mediaQuery.copyWith(size: Size(width, 800)),
                  child: Builder(
                    builder: (context) {
                      final crossAxisCount = GridLayoutHelper.calculateCrossAxisCount(context);
                      return Text('CrossAxisCount: $crossAxisCount');
                    },
                  ),
                );
              }

              return Column(
                children: [
                  testWidget(1300), // Should be 4
                  testWidget(900),  // Should be 3
                  testWidget(600),  // Should be 2
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('CrossAxisCount: 4'), findsOneWidget);
      expect(find.text('CrossAxisCount: 3'), findsOneWidget);
      expect(find.text('CrossAxisCount: 2'), findsOneWidget);
    });

    testWidgets('ProgressiveLoadingGrid renders correctly', (WidgetTester tester) async {
      final items = List.generate(5, (index) => 
        Container(
          key: ValueKey('item_$index'),
          child: Text('Item $index'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressiveLoadingGrid(
              items: items,
              itemsPerBatch: 5,
              batchDelay: const Duration(milliseconds: 10),
            ),
          ),
        ),
      );

      // Check that the ProgressiveLoadingGrid widget is rendered
      expect(find.byType(ProgressiveLoadingGrid), findsOneWidget);
      
      // Wait for items to load
      await tester.pumpAndSettle();
      
      // Should have at least some items rendered
      expect(find.text('Item 0'), findsOneWidget);
    });
  });
}