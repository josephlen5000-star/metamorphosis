import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PlateDividerPainter extends CustomPainter {
  const PlateDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.plateDivider
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final midX = size.width / 2;
    final leftSplitY = size.height * 0.40;
    final rightSplitY = size.height * 0.60;

    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
    canvas.drawLine(Offset(0, leftSplitY), Offset(midX, leftSplitY), paint);
    canvas.drawLine(
      Offset(midX, rightSplitY),
      Offset(size.width, rightSplitY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
