import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../models/nearby_place.dart';

/// Full-width vertical card for the "Phổ biến nhất" section.
///
/// Displays place info in a horizontal layout similar to [PlaceCard]
/// but designed for [NearbyPlace] data from OpenStreetMap.
class PopularPlaceCard extends StatelessWidget {
  const PopularPlaceCard({
    super.key,
    required this.place,
    required this.index,
    required this.onTap,
  });

  final NearbyPlace place;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = _indexGradient(index);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              // Rank number with gradient circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Place info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    if (place.address.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              place.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (place.phone != null || place.openingHours != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (place.phone != null)
                            Icon(Icons.phone_rounded,
                                size: 12,
                                color: AppColors.primary.withValues(alpha: 0.7)),
                          if (place.phone != null && place.openingHours != null)
                            const SizedBox(width: 6),
                          if (place.openingHours != null)
                            Icon(Icons.access_time_rounded,
                                size: 12,
                                color: AppColors.primary.withValues(alpha: 0.7)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Category badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  place.category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient for rank number badge – top 3 get gold/silver/bronze,
/// rest get a neutral teal.
LinearGradient _indexGradient(int index) {
  return switch (index) {
    0 => const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
      ),
    1 => const LinearGradient(
        colors: [Color(0xFFC0C0C0), Color(0xFF9E9E9E)],
      ),
    2 => const LinearGradient(
        colors: [Color(0xFFCD7F32), Color(0xFF8D6E63)],
      ),
    _ => LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
  };
}
