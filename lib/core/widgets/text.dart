import 'package:flutter/material.dart';

class MyText extends StatelessWidget {
  final String text;

  final bool isMainHeading;
  final bool isSubHeading;
  final bool isSimpleText;
  final double letterSpacing;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final Color? color;
  final String? fontFamily;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextDecoration? decoration;
  final double? height;
  final FontStyle? fontStyle;

  const MyText({
    super.key,
    required this.text,
    this.isMainHeading = false,
    this.isSubHeading = false,
    this.isSimpleText = false,
    this.letterSpacing = 0.5,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.color,
    this.fontFamily,
    this.maxLines,
    this.overflow,
    this.decoration,
    this.height,
    this.fontStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        decoration: decoration ?? TextDecoration.none,
        letterSpacing: letterSpacing,
        height: height,
        fontFamily: fontFamily ?? 'Outfit',
        fontStyle: fontStyle,
        color: color ?? Colors.black,
        fontSize: fontSize ??
            (isMainHeading
                ? 38
                : isSubHeading
                    ? 28
                    : isSimpleText
                        ? 17
                        : 15),
        fontWeight: fontWeight ?? (isMainHeading || isSubHeading ? FontWeight.w800 : FontWeight.w500),
      ),
    );
  }
}
