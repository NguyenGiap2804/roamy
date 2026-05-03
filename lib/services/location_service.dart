import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Wrapper around [Geolocator] that handles permission flow and provides
/// a cached location with a configurable TTL.
///
/// Uses a singleton pattern (like [NotificationService]) so the same instance
/// is shared between `main.dart` (early permission request) and the provider
/// tree.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Default fallback: Hanoi, Vietnam.
  static const defaultLatitude = 21.0285;
  static const defaultLongitude = 105.8542;
  static const defaultCityName = 'Hà Nội';

  static const _cacheDuration = Duration(minutes: 5);

  Position? _cachedPosition;
  DateTime? _cacheTimestamp;
  String _cityName = defaultCityName;

  /// The display name of the detected city (fallback: "Hà Nội").
  String get cityName => _cityName;

  /// Whether the last location result was a fallback (not real GPS).
  bool get isFallback => _cachedPosition == null;

  /// Get the current position. Returns a cached value if it is less than
  /// [_cacheDuration] old. Falls back to Hanoi coordinates on any failure.
  Future<({double latitude, double longitude})> getCurrentLocation() async {
    // Return cached if still valid.
    if (_cachedPosition != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return (
        latitude: _cachedPosition!.latitude,
        longitude: _cachedPosition!.longitude,
      );
    }

    try {
      final position = await _determinePosition();
      _cachedPosition = position;
      _cacheTimestamp = DateTime.now();
      _cityName = 'Vị trí của bạn';
      debugPrint('LocationService: GPS lat=${position.latitude}, '
          'lng=${position.longitude}, accuracy=${position.accuracy}m');
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (error) {
      debugPrint('LocationService fallback: $error');
      _cityName = defaultCityName;
      return (latitude: defaultLatitude, longitude: defaultLongitude);
    }
  }

  /// Force-refresh the location by clearing the cache.
  void invalidateCache() {
    _cachedPosition = null;
    _cacheTimestamp = null;
  }

  /// Determine position with full permission handling.
  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }
}
