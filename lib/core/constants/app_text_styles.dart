import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const headline = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const subtitle = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}
