import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'history_icon_button.dart';
import 'user_icon_button.dart';

class TopTitleBar extends CupertinoNavigationBar {
  TopTitleBar({
    super.key,
    VoidCallback? onProfilePressed,
    VoidCallback? onHistoryPressed,
  }) : super(
        backgroundColor: AppColors.chrome,
        border: const Border(
          bottom: BorderSide(color: AppColors.toolbarDivider, width: 0.5),
        ),
        leading: UserIconButton(onPressed: onProfilePressed),
        trailing: HistoryIconButton(onPressed: onHistoryPressed),
        middle: const Text(
          'Metamorphosis',
          style: AppStyle.navTitle,
        ),
      );
}
