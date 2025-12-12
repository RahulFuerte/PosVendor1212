import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/frontend/screen.dart';
import 'package:pos/view/tab_screen/view-model/frontend/text_styles.dart';

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final Widget prefixIcon;
  final List<String>? autoFillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.autoFillHints,
    this.keyboardType,
    this.onChanged,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final Screen s = Screen(context);
    final MyTextStyle ts = MyTextStyle();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 8 * s.customWidth,
          vertical: 5 * s.customWidth,
        ),
        child: TextFormField(
          // cursorColor: theme,
          cursorColor: Colors.black,
          style: TextStyle(fontSize: 18.2 * s.customWidth, letterSpacing: 1),
          controller: controller,
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          autofillHints: autoFillHints,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          inputFormatters: [
            FilteringTextInputFormatter.deny(regExpEmojis),
            ...inputFormatters!,
          ],
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintStyle: ts.buttonText.copyWith(color: grey),
          ),
        ),
      ),
    );
  }
}

class PrefixIcon91 extends StatelessWidget {
  const PrefixIcon91(
    this.s, {
    Key? key,
  }) : super(key: key);

  final Screen s;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      child: Text(
        "+91",
        style: TextStyle(
          // color: theme,
          color: black,
          fontSize: 17 * s.customWidth,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
