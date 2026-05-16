import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderTypeSelector extends StatelessWidget {
  const OrderTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderTypeProvider>();
    final selected = provider.orderType;

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        String category = 'Food';
        if (snapshot.hasData) {
          category = snapshot.data!.getString('businessCategory') ?? 'Food';
        }

        if (category != 'Food') {
          return const SizedBox.shrink();
        }

        return Row(
          children: [
            _item(context, category == 'Food' ? "Dine In" : "In-Store", OrderType.dineIn, selected),
            _item(context, category == 'Food' ? "Pick Up" : "Takeaway", OrderType.pickUp, selected),
            _item(context, "Delivery", OrderType.delivery, selected),
          ],
        );
      },
    );
  }

  Widget _item(
    BuildContext context,
    String text,
    OrderType type,
    OrderType selected,
  ) {
    final bool isSelected = selected == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<OrderTypeProvider>().setOrderType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? appbar1 : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? appbar1 : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: Center(
            child: MyText(
              text: text,
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
