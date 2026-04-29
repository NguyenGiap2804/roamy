import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.secondary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expanded;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = FilledButton.styleFrom(
      backgroundColor: secondary
          ? (isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.primarySoft)
          : AppColors.primary,
      foregroundColor: secondary
          ? (isDark ? Colors.white : AppColors.primaryDark)
          : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = FilledButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
