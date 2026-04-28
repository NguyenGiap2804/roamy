import 'package:flutter/material.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.placeCount = 0,
  });

  final String id;
  final String name;
  final String icon;
  final int placeCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: (json['icon'] as String?) ?? 'category',
      placeCount: count is Map<String, dynamic>
          ? (count['places'] as num?)?.toInt() ?? 0
          : (json['placeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'icon': icon};
  }

  IconData get iconData {
    return switch (icon) {
      'local_cafe' => Icons.local_cafe_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'movie' => Icons.movie_rounded,
      'flight_takeoff' => Icons.flight_takeoff_rounded,
      'favorite' => Icons.favorite_rounded,
      'work' => Icons.work_rounded,
      _ => Icons.category_rounded,
    };
  }
}

typedef PlaceCategory = Category;
