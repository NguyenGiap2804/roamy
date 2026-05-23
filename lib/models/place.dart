import '../core/utils/coordinates.dart';

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.address,
    required this.priceRange,
    required this.openingHours,
    this.phone,
    this.website,
    this.mapsUrl,
    this.note,
    this.imageUrl,
    required this.rating,
    required this.hasReminder,
    this.categoryName,
    this.latitude,
    this.longitude,
    this.isPendingSync = false,
  });

  final String id;
  final String name;
  final String categoryId;
  final String address;
  final String priceRange;
  final String openingHours;
  final String? phone;
  final String? website;
  final String? mapsUrl;
  final String? note;
  final String? imageUrl;
  final double rating;
  final bool hasReminder;
  final String? categoryName;
  final double? latitude;
  final double? longitude;
  final bool isPendingSync;

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
      website: json['website'] as String?,
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
      isPendingSync: false,
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
      'website': website,
      'mapsUrl': mapsUrl,
      'note': note,
      'imageUrl': imageUrl,
      'rating': rating,
      'hasReminder': hasReminder,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Place copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? address,
    String? priceRange,
    String? openingHours,
    Object? phone = _unset,
    Object? website = _unset,
    Object? mapsUrl = _unset,
    Object? note = _unset,
    Object? imageUrl = _unset,
    double? rating,
    bool? hasReminder,
    Object? categoryName = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    bool? isPendingSync,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      address: address ?? this.address,
      priceRange: priceRange ?? this.priceRange,
      openingHours: openingHours ?? this.openingHours,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      website: identical(website, _unset) ? this.website : website as String?,
      mapsUrl: identical(mapsUrl, _unset) ? this.mapsUrl : mapsUrl as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      imageUrl: identical(imageUrl, _unset)
          ? this.imageUrl
          : imageUrl as String?,
      rating: rating ?? this.rating,
      hasReminder: hasReminder ?? this.hasReminder,
      categoryName: identical(categoryName, _unset)
          ? this.categoryName
          : categoryName as String?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  String get category => categoryName ?? 'Other';
  bool get hasPriceRange => priceRange.trim().isNotEmpty;
  bool get hasOpeningHours => openingHours.trim().isNotEmpty;
  bool get hasPhone => phone?.trim().isNotEmpty == true;
  bool get hasWebsite => website?.trim().isNotEmpty == true;
  bool get hasMapsUrl => mapsUrl?.trim().isNotEmpty == true;
  bool get hasCoordinates => hasUsableCoordinates(latitude, longitude);
  String get safePhone => phone?.isNotEmpty == true ? phone! : 'Not added yet';
  String get safeWebsite =>
      website?.isNotEmpty == true ? website! : 'Not added yet';
  String get safeMapsUrl =>
      mapsUrl?.isNotEmpty == true ? mapsUrl! : 'Not added yet';
  String get safeNote =>
      note?.isNotEmpty == true ? note! : 'No personal note yet.';
  String get safeImageUrl => imageUrl ?? '';
}

const Object _unset = Object();
