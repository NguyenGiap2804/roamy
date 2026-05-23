import '../core/utils/coordinates.dart';
import '../core/utils/google_maps_urls.dart';

/// A place discovered from external APIs (OpenStreetMap) in real-time.
///
/// This is intentionally separate from [Place] because the data shape and
/// lifecycle are different: NearbyPlace is ephemeral (fetched in real-time,
/// never persisted locally), while Place is a user-saved entity in the DB.
class NearbyPlace {
  const NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.rating,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    required this.category,
    required this.categoryBase,
    this.openingHours,
    this.phone,
    this.website,
    this.cuisine,
    required this.mapsUrl,
  });

  /// Unique identifier (OSM node ID or Nominatim place_id).
  final String placeId;

  /// Display name of the place.
  final String name;

  /// Address or location description.
  final String address;

  /// Internal quality score used for sorting nearby results, not a user rating.
  final double rating;

  /// GPS coordinates.
  final double latitude;
  final double longitude;

  /// Photo URL. Null if no photo available (UI shows fallback icon).
  final String? photoUrl;

  /// Category with emoji (e.g. "Cafe ☕", "Nhà hàng 🍜").
  final String category;

  /// Category without emoji – used for filtering (e.g. "Cafe", "Nhà hàng").
  final String categoryBase;

  /// Opening hours text (from OSM tags).
  final String? openingHours;

  /// Phone number (from OSM tags).
  final String? phone;

  /// Website URL (from OSM tags).
  final String? website;

  /// Cuisine type (from OSM tags).
  final String? cuisine;

  /// Google Maps URL for navigation/search.
  final String mapsUrl;

  /// Safe image URL that returns empty string if null.
  String get safeImageUrl => photoUrl ?? '';

  /// Whether this place has a usable internal quality score.
  bool get hasRating => rating > 0;

  Map<String, dynamic> toAddPlaceDraft({
    String? name,
    String? resolvedAddress,
    String? address,
    double? rating,
    String? priceRange,
    String? openingHours,
    String? phone,
    String? website,
    String? imageUrl,
  }) {
    final draft = <String, dynamic>{
      'name': _firstNonBlank(name, this.name) ?? '',
      'address': _firstNonBlank(address, resolvedAddress, this.address) ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'mapsUrl': mapsUrl,
    };

    if (_isGoogleRating(rating)) {
      draft['rating'] = rating;
    }

    final selectedPriceRange = _firstNonBlank(priceRange);
    if (selectedPriceRange != null) draft['priceRange'] = selectedPriceRange;
    final selectedImageUrl = _firstNonBlank(imageUrl, photoUrl);
    if (selectedImageUrl != null) draft['imageUrl'] = selectedImageUrl;
    final hours = _firstNonBlank(openingHours, this.openingHours);
    if (hours != null) draft['openingHours'] = hours;
    final phoneNumber = _firstNonBlank(phone, this.phone);
    if (phoneNumber != null) draft['phone'] = phoneNumber;
    final websiteUrl = _firstNonBlank(website, this.website);
    if (websiteUrl != null) draft['website'] = websiteUrl;

    return draft;
  }

  /// Create a copy with updated fields (used for photo enrichment).
  NearbyPlace copyWith({String? photoUrl}) {
    return NearbyPlace(
      placeId: placeId,
      name: name,
      address: address,
      rating: rating,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl ?? this.photoUrl,
      category: category,
      categoryBase: categoryBase,
      openingHours: openingHours,
      phone: phone,
      website: website,
      cuisine: cuisine,
      mapsUrl: mapsUrl,
    );
  }

  /// Create from Overpass API response element.
  factory NearbyPlace.fromOverpassJson(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};

    final coordinates = _readOverpassCoordinates(element);
    if (coordinates == null) {
      throw const FormatException('Nearby place is missing coordinates');
    }
    final lat = coordinates.$1;
    final lng = coordinates.$2;

    final id = element['id'].toString();

    final name =
        (tags['official_name'] as String?) ??
        (tags['name'] as String?) ??
        (tags['name:vi'] as String?) ??
        (tags['alt_name'] as String?) ??
        (tags['name:en'] as String?) ??
        '';

    final catInfo = _mapOsmType(tags);

    final address = _buildAddress(tags);

    return NearbyPlace(
      placeId: id,
      name: name,
      address: address,
      rating: _computeQualityRating(tags),
      latitude: lat,
      longitude: lng,
      photoUrl: _extractOsmPhotoUrl(tags, lat, lng),
      category: catInfo.$1,
      categoryBase: catInfo.$2,
      openingHours: tags['opening_hours'] as String?,
      phone: (tags['phone'] ?? tags['contact:phone']) as String?,
      website: (tags['website'] ?? tags['contact:website']) as String?,
      cuisine: tags['cuisine'] as String?,
      mapsUrl: buildGoogleMapsSearchUrl(
        name: name,
        address: address,
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  /// Create from Nominatim search response.
  factory NearbyPlace.fromNominatimJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lng = double.tryParse(json['lon']?.toString() ?? '');
    if (!hasUsableCoordinates(lat, lng)) {
      throw const FormatException('Nearby place is missing coordinates');
    }

    final id = json['place_id']?.toString() ?? '';

    final displayName = json['display_name'] as String? ?? '';
    final parts = displayName.split(', ');
    final name = parts.isNotEmpty ? parts[0] : displayName;
    final address = parts.length > 2
        ? parts.sublist(1, 3).join(', ')
        : displayName;

    final type = json['type'] as String? ?? '';
    final jsonCategory = json['category'] as String? ?? '';
    final catInfo = _mapNominatimType(jsonCategory, type);

    return NearbyPlace(
      placeId: id,
      name: name,
      address: address,
      rating: _computeNominatimRating(json),
      latitude: lat!,
      longitude: lng!,
      photoUrl: _staticMapUrl(lat, lng),
      category: catInfo.$1,
      categoryBase: catInfo.$2,
      mapsUrl: buildGoogleMapsSearchUrl(
        name: name,
        address: address,
        latitude: lat,
        longitude: lng,
      ),
    );
  }
}

bool _isGoogleRating(double? value) {
  return value != null && value >= 1.0 && value <= 5.0;
}

String? _firstNonBlank(
  String? primary, [
  String? fallback,
  String? secondFallback,
]) {
  for (final value in [primary, fallback, secondFallback]) {
    if (value == null) continue;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

(double, double)? _readOverpassCoordinates(Map<String, dynamic> element) {
  double? lat;
  double? lng;

  final rawLat = element['lat'];
  final rawLng = element['lon'];
  if (rawLat is num && rawLng is num) {
    lat = rawLat.toDouble();
    lng = rawLng.toDouble();
  } else {
    final center = element['center'];
    if (center is Map<String, dynamic>) {
      final centerLat = center['lat'];
      final centerLng = center['lon'];
      if (centerLat is num && centerLng is num) {
        lat = centerLat.toDouble();
        lng = centerLng.toDouble();
      }
    }
  }

  if (!hasUsableCoordinates(lat, lng)) return null;
  return (lat!, lng!);
}

/// Try to get a photo URL from OSM tags, fallback to a static map.
String _extractOsmPhotoUrl(Map<String, dynamic> tags, double lat, double lng) {
  // 1. Direct image URL from OSM.
  final image = tags['image'] as String?;
  if (image != null && image.startsWith('http')) return image;

  // 2. Wikimedia Commons file reference → construct URL.
  final commons = tags['wikimedia_commons'] as String?;
  if (commons != null && commons.startsWith('File:')) {
    final fileName = commons.substring(5).replaceAll(' ', '_');
    return 'https://commons.wikimedia.org/wiki/Special:FilePath/$fileName?width=400';
  }

  // 3. Fallback: static map image showing location.
  return _staticMapUrl(lat, lng);
}

/// Generate a static map image URL from coordinates.
/// Uses OpenStreetMap's free static map service.
String _staticMapUrl(double lat, double lng) {
  return 'https://staticmap.openstreetmap.de/staticmap.php'
      '?center=$lat,$lng'
      '&zoom=17'
      '&size=400x300'
      '&maptype=mapnik'
      '&markers=$lat,$lng,red-pushpin';
}

/// Build a short address from OSM tags.
String _buildAddress(Map<String, dynamic> tags) {
  final parts = <String>[
    if (tags['addr:housenumber'] != null) tags['addr:housenumber'] as String,
    if (tags['addr:street'] != null) tags['addr:street'] as String,
    if (tags['addr:hamlet'] != null) tags['addr:hamlet'] as String,
    if (tags['addr:subdistrict'] != null) tags['addr:subdistrict'] as String,
    if (tags['addr:district'] != null) tags['addr:district'] as String,
    if (tags['addr:city'] != null) tags['addr:city'] as String,
  ];
  if (parts.isNotEmpty) return parts.join(', ');

  // Fallback: try any known administrative tags in order
  final street = tags['addr:full'] as String?;
  if (street != null && street.trim().isNotEmpty) return street.trim();

  return ''; // Empty — will be filled via reverse geocode in the UI layer
}

/// Map OSM tags to (categoryWithEmoji, categoryBase) pair.
(String, String) _mapOsmType(Map<String, dynamic> tags) {
  final amenity = tags['amenity'] as String?;
  final tourism = tags['tourism'] as String?;
  final leisure = tags['leisure'] as String?;
  final shop = tags['shop'] as String?;

  if (amenity != null) {
    return switch (amenity) {
      'cafe' || 'coffee_shop' => ('Cafe ☕', 'Cafe'),
      'restaurant' ||
      'food_court' ||
      'fast_food' => ('Nhà hàng 🍜', 'Nhà hàng'),
      'bar' || 'pub' || 'nightclub' => ('Bar 🍸', 'Bar'),
      'cinema' => ('Rạp phim 🎬', 'Rạp phim'),
      'pharmacy' => ('Nhà thuốc 💊', 'Nhà thuốc'),
      'bank' || 'atm' => ('Ngân hàng 🏦', 'Ngân hàng'),
      'hospital' || 'clinic' || 'doctors' => ('Y tế 🏥', 'Y tế'),
      'school' || 'university' || 'college' => ('Giáo dục 🎓', 'Giáo dục'),
      'fuel' => ('Xăng dầu ⛽', 'Xăng dầu'),
      'parking' => ('Bãi đỗ xe 🅿️', 'Bãi đỗ xe'),
      _ => ('Tiện ích 📍', 'Tiện ích'),
    };
  }
  if (tourism != null) {
    return switch (tourism) {
      'hotel' ||
      'motel' ||
      'guest_house' ||
      'hostel' => ('Khách sạn 🏨', 'Khách sạn'),
      'attraction' || 'museum' || 'viewpoint' => ('Tham quan 🗺️', 'Tham quan'),
      _ => ('Du lịch 🧳', 'Du lịch'),
    };
  }
  if (leisure != null) {
    return switch (leisure) {
      'park' || 'garden' => ('Công viên 🌳', 'Công viên'),
      'sports_centre' ||
      'stadium' ||
      'fitness_centre' => ('Thể thao ⚽', 'Thể thao'),
      'playground' => ('Khu vui chơi 🎠', 'Khu vui chơi'),
      _ => ('Giải trí 🎭', 'Giải trí'),
    };
  }
  if (shop != null) {
    return switch (shop) {
      'supermarket' || 'convenience' => ('Siêu thị 🛒', 'Siêu thị'),
      'clothes' || 'fashion' => ('Thời trang 👗', 'Thời trang'),
      'bakery' => ('Tiệm bánh 🍰', 'Tiệm bánh'),
      _ => ('Cửa hàng 🛍️', 'Cửa hàng'),
    };
  }
  return ('Địa điểm 📍', 'Địa điểm');
}

/// Map Nominatim category/type to (categoryWithEmoji, categoryBase).
(String, String) _mapNominatimType(String category, String type) {
  if (category == 'amenity') return _mapOsmType({'amenity': type});
  if (category == 'tourism') return _mapOsmType({'tourism': type});
  if (category == 'leisure') return _mapOsmType({'leisure': type});
  if (category == 'shop') return _mapOsmType({'shop': type});
  return ('Địa điểm 📍', 'Địa điểm');
}

/// Compute a popularity score (0.0–10.0) based on OSM data completeness.
/// Used internally for sorting "Phổ biến nhất" – NOT shown as star rating.
double _computeQualityRating(Map<String, dynamic> tags) {
  double score = 1.0; // Base score

  // Well-established businesses have more OSM data.
  if (tags['opening_hours'] != null) score += 1.5;
  if (tags['phone'] != null || tags['contact:phone'] != null) score += 1.5;
  if (tags['website'] != null || tags['contact:website'] != null) score += 1.0;
  if (tags['addr:street'] != null) score += 0.8;
  if (tags['addr:housenumber'] != null) score += 0.5;
  if (tags['cuisine'] != null) score += 0.7;
  if (tags['brand'] != null) score += 1.0;
  if (tags['wheelchair'] != null) score += 0.3;
  if (tags['internet_access'] != null) score += 0.5;
  if (tags['image'] != null || tags['wikimedia_commons'] != null) score += 1.0;
  if (tags['wikidata'] != null) score += 1.0;
  if (tags['description'] != null) score += 0.5;

  return score.clamp(0.0, 10.0);
}

/// Compute popularity for Nominatim results based on importance.
double _computeNominatimRating(Map<String, dynamic> json) {
  final importance = (json['importance'] as num?)?.toDouble() ?? 0.0;
  return (importance * 10.0).clamp(0.0, 10.0);
}
