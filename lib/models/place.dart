class Place {
  const Place({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.address,
    required this.priceRange,
    required this.openingHours,
    this.phone,
    this.mapsUrl,
    this.note,
    this.imageUrl,
    required this.rating,
    required this.hasReminder,
    this.categoryName,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String categoryId;
  final String address;
  final String priceRange;
  final String openingHours;
  final String? phone;
  final String? mapsUrl;
  final String? note;
  final String? imageUrl;
  final double rating;
  final bool hasReminder;
  final String? categoryName;
  final double? latitude;
  final double? longitude;

  factory Place.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String,
      address: json['address'] as String,
      priceRange: json['priceRange'] as String,
      openingHours: json['openingHours'] as String,
      phone: json['phone'] as String?,
      mapsUrl: json['mapsUrl'] as String?,
      note: json['note'] as String?,
      imageUrl: json['imageUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      hasReminder: (json['hasReminder'] as bool?) ?? false,
      categoryName: category is Map<String, dynamic>
          ? category['name'] as String?
          : json['categoryName'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'categoryId': categoryId,
      'address': address,
      'priceRange': priceRange,
      'openingHours': openingHours,
      'phone': phone,
      'mapsUrl': mapsUrl,
      'note': note,
      'imageUrl': imageUrl,
      'rating': rating,
      'hasReminder': hasReminder,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get category => categoryName ?? 'Other';
  bool get hasPriceRange => priceRange.trim().isNotEmpty;
  bool get hasOpeningHours => openingHours.trim().isNotEmpty;
  bool get hasPhone => phone?.trim().isNotEmpty == true;
  bool get hasMapsUrl => mapsUrl?.trim().isNotEmpty == true;
  String get safePhone => phone?.isNotEmpty == true ? phone! : 'Not added yet';
  String get safeMapsUrl =>
      mapsUrl?.isNotEmpty == true ? mapsUrl! : 'Not added yet';
  String get safeNote =>
      note?.isNotEmpty == true ? note! : 'No personal note yet.';
  String get safeImageUrl => imageUrl ?? '';
}
