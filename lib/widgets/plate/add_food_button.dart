import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AddFoodButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const AddFoodButton({super.key, this.onPressed, this.size = 74});

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.51;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.addButton,
          border: Border.all(color: AppColors.plateRim, width: 4),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(Icons.add, color: Colors.white, size: iconSize),
      ),
    );
  }
}

class AddFoodChip extends StatelessWidget {
  const AddFoodChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.plateWell,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4DDD2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 14,
            color: AppColors.accent,
          ),
          SizedBox(width: 4),
          Text(
            'Add food',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
