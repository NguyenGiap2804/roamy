import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.compact = false});

  final double rating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor().clamp(0, 5);
    final hasHalfStar = rating - fullStars >= 0.5 && fullStars < 5;
    final size = compact ? 15.0 : 18.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 5; index++)
          Icon(
            index < fullStars
                ? Icons.star_rounded
                : index == fullStars && hasHalfStar
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: AppColors.star,
          ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
