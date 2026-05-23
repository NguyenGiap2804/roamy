import 'coordinates.dart';

Uri buildGoogleMapsSearchUri({
  String? name,
  String? address,
  double? latitude,
  double? longitude,
}) {
  final cleanedName = _clean(name);
  final cleanedAddress = _clean(address);

  if (cleanedName != null) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': [cleanedName, ?cleanedAddress].join(', '),
    });
  }

  if (hasUsableCoordinates(latitude, longitude)) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${latitude!},${longitude!}',
    });
  }

  return Uri.https('www.google.com', '/maps');
}

String buildGoogleMapsSearchUrl({
  String? name,
  String? address,
  double? latitude,
  double? longitude,
}) {
  return buildGoogleMapsSearchUri(
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
  ).toString();
}

Uri? buildGoogleMapsLaunchUri({
  String? mapsUrl,
  String? name,
  String? address,
  double? latitude,
  double? longitude,
}) {
  final savedUri = _parseNonCoordinateOnlyUri(mapsUrl);
  if (savedUri != null) return savedUri;

  if (_clean(name) != null || hasUsableCoordinates(latitude, longitude)) {
    return buildGoogleMapsSearchUri(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  final cleanedMapsUrl = _clean(mapsUrl);
  return cleanedMapsUrl == null ? null : Uri.tryParse(cleanedMapsUrl);
}

Uri? _parseNonCoordinateOnlyUri(String? value) {
  final cleaned = _clean(value);
  if (cleaned == null) return null;

  final uri = Uri.tryParse(cleaned);
  if (uri == null) return null;
  if (_isCoordinateOnlyMapsUri(uri)) return null;
  return uri;
}

bool _isCoordinateOnlyMapsUri(Uri uri) {
  if (uri.scheme == 'geo') return true;

  final query = uri.queryParameters['query'] ?? uri.queryParameters['q'];
  if (query != null && _isCoordinatePair(query)) return true;

  final decoded = Uri.decodeFull(uri.toString());
  if (decoded.contains('/maps/place/')) return false;
  return RegExp(r'[@?&=/]-?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?').hasMatch(decoded);
}

bool _isCoordinatePair(String value) {
  return RegExp(r'^\s*-?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?\s*$').hasMatch(value);
}

String? _clean(String? value) {
  if (value == null) return null;
  final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? null : cleaned;
}
