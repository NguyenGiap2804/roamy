import '../models/category.dart';

const mockCategories = <PlaceCategory>[
  PlaceCategory(id: 'cafe', name: 'Cafe', icon: 'local_cafe', placeCount: 2),
  PlaceCategory(id: 'food', name: 'Food', icon: 'restaurant', placeCount: 4),
  PlaceCategory(id: 'movie', name: 'Movie', icon: 'movie', placeCount: 1),
  PlaceCategory(
    id: 'travel',
    name: 'Travel',
    icon: 'flight_takeoff',
    placeCount: 3,
  ),
  PlaceCategory(id: 'date', name: 'Date', icon: 'favorite', placeCount: 2),
  PlaceCategory(id: 'work', name: 'Work', icon: 'work', placeCount: 1),
  PlaceCategory(id: 'other', name: 'Other', icon: 'category', placeCount: 0),
];
