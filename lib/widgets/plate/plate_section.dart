import 'package:flutter/material.dart';

class PlateSection extends StatelessWidget {
  const PlateSection({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    this.alignment = Alignment.center,
    this.padding = EdgeInsets.zero,
    this.fontSize = 14,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Alignment alignment;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}
