import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../models/nearby_place.dart';
import '../models/place.dart';

/// A compact horizontal-scroll card used in the Explore Home Screen.
///
/// Shows a category-based gradient background with emoji when no photo
/// is available (common for OpenStreetMap data).
class ExplorePlaceCard extends StatelessWidget {
  const ExplorePlaceCard({
    super.key,
    required this.name,
    required this.address,
    required this.rating,
    required this.category,
    required this.imageUrl,
    required this.onTap,
  });

  factory ExplorePlaceCard.fromPlace({
    Key? key,
    required Place place,
    required VoidCallback onTap,
  }) {
    return ExplorePlaceCard(
      key: key,
      name: place.name,
      address: place.address,
      rating: place.rating,
      category: place.category,
      imageUrl: place.safeImageUrl,
      onTap: onTap,
    );
  }

  factory ExplorePlaceCard.fromNearby({
    Key? key,
    required NearbyPlace place,
    required VoidCallback onTap,
  }) {
    return ExplorePlaceCard(
      key: key,
      name: place.name,
      address: place.address,
      rating: place.rating,
      category: place.category,
      imageUrl: place.safeImageUrl,
      onTap: onTap,
    );
  }

  final String name;
  final String address;
  final double rating;
  final String category;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = _categoryGradient(category);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withValues(alpha: 0.15),
      elevation: 5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 170,
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: gradient,
          ),
          child: Stack(
            children: [
              // Background image if available
              if (imageUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),

              // Category badge (top-left)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // Content at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vibrant gradient per category for cards without photos.
LinearGradient _categoryGradient(String category) {
  if (category.contains('Cafe')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B6914), Color(0xFF5D4037)],
    );
  }
  if (category.contains('Nhà hàng')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE65100), Color(0xFFBF360C)],
    );
  }
  if (category.contains('Khách sạn')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    );
  }
  if (category.contains('Bar')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
    );
  }
  if (category.contains('Rạp phim')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC62828), Color(0xFF880E4F)],
    );
  }
  if (category.contains('Công viên')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    );
  }
  if (category.contains('Thể thao')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00838F), Color(0xFF006064)],
    );
  }
  if (category.contains('Siêu thị') || category.contains('Cửa hàng')) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF6F00), Color(0xFFE65100)],
    );
  }
  // Default
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );
}
