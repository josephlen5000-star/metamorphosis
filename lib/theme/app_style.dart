import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppStyle {
  const AppStyle._();

  static const double cardRadius = 16;
  static const double fieldRadius = 12;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 32);
  static const EdgeInsets foodRowPadding = EdgeInsets.fromLTRB(16, 14, 8, 14);

  static const BoxDecoration card = BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );

  static final BoxDecoration field = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(fieldRadius),
    border: Border.all(color: AppColors.toolbarDivider),
  );

  static const BoxDecoration searchField = card;

  static const Border navBorder = Border(
    bottom: BorderSide(color: AppColors.toolbarDivider, width: 0.5),
  );

  static const TextStyle navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle subsectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle accentAction = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.accent,
  );

  static const TextStyle navAction = TextStyle(
    fontSize: 17,
    color: AppColors.textSecondary,
  );

  static const TextStyle navActionAccent = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.accent,
  );

  static const TextStyle heroValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static Widget? backButton(
    BuildContext context, {
    String? previousPageTitle,
  }) {
    if (ModalRoute.of(context)?.canPop != true) return null;
    return CupertinoNavigationBarBackButton(
      color: AppColors.accent,
      previousPageTitle: previousPageTitle,
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  static Widget iconAction({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }
}
