import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/view/home/navigation.dart';

class MyChoiceChip extends StatelessWidget {
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const MyChoiceChip({super.key, required this.options, required this.selectedValue, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: options.map((value) {
        final isSelected = selectedValue == value;
        return ChoiceChip(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 7),
          label: MyText(
            text: value,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: appbar1,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}
