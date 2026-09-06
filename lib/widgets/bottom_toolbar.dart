import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BottomToolbar extends StatelessWidget {
  const BottomToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.chrome,
        border: Border(
          top: BorderSide(color: AppColors.toolbarDivider, width: 0.5),
        ),
      ),
      child: const Row(
        children: [
          Expanded(child: SizedBox.expand()),
          Expanded(child: SizedBox.expand()),
          Expanded(child: SizedBox.expand()),
          Expanded(child: SizedBox.expand()),
          Expanded(child: SizedBox.expand()),
        ],
      ),
    );
  }
}
