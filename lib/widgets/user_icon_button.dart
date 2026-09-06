import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

class UserIconButton extends StatelessWidget {
  const UserIconButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: const Icon(
          CupertinoIcons.person_circle,
          color: AppColors.textPrimary,
          size: 48.0,
        ),
      ),
    );
  }
}
