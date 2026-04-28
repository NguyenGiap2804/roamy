import 'package:flutter/material.dart';

import '../core/constants/app_text_styles.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(title, style: AppTextStyles.title)),
      ],
    );
  }
}
