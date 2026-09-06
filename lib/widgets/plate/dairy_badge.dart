import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class DairyBadge extends StatelessWidget {
  const DairyBadge({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.dairy,
        border: Border.all(color: AppColors.plateRim, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Dairy',
          style: TextStyle(
            color: AppColors.dairyText,
            fontSize: size * 0.20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
