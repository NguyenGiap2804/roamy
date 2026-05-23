import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/nearby_place.dart';

/// Service that fetches real-world places using free OpenStreetMap APIs
/// and enriches them with photos from Wikimedia Commons.
///
/// - **Overpass API**: Nearby search (cafes, restaurants, hotels, etc.)
/// - **Nominatim**: Text search by name/type
/// - **Wikimedia Commons**: Photo enrichment (geosearch)
///
/// All APIs are 100% free, no API key, no billing required.
class ExploreApiService {
  ExploreApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const _overpassMirrorUrl =
      'https://overpass.kumi.systems/api/interpreter';
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  static const _wikimediaUrl = 'https://commons.wikimedia.org/w/api.php';
  static const _cacheDuration = Duration(minutes: 5);
  static const _maxCacheEntries = 20;
  static const _userAgent = 'RoamyApp/1.0 (portfolio project)';

  final Map<String, _CacheEntry> _cache = {};

  /// Search for nearby places using Overpass API, then enrich with photos.
  Future<List<NearbyPlace>> searchNearby({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int maxResults = 50,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(3)}_'
        '${longitude.toStringAsFixed(3)}_nearby';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      debugPrint('ExploreApiService: cache hit (nearby)');
      return cached.data;
    }

    // Try primary server, then mirror if it fails
    try {
      return await _fetchFromOverpass(
        url: _overpassUrl,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        maxResults: maxResults,
        cacheKey: cacheKey,
      );
    } catch (e) {
      debugPrint(
        'ExploreApiService: Primary Overpass failed, trying mirror... ($e)',
      );
      try {
        return await _fetchFromOverpass(
          url: _overpassMirrorUrl,
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          maxResults: maxResults,
          cacheKey: cacheKey,
        );
      } catch (mirrorError) {
        debugPrint('ExploreApiService: All Overpass servers failed');
        if (cached != null) return cached.data;
        rethrow;
      }
    }
  }

  Future<List<NearbyPlace>> _fetchFromOverpass({
    required String url,
    required double latitude,
    required double longitude,
    required double radius,
    required int maxResults,
    required String cacheKey,
  }) async {
    final query =
        '''
[out:json][timeout:30];
(
  nw(around:$radius,$latitude,$longitude)["amenity"~"cafe|restaurant|fast_food|bar|pub|cinema|hospital|pharmacy|bank|fuel"];
  nw(around:$radius,$latitude,$longitude)["tourism"~"hotel|motel|guest_house|hostel|attraction|museum"];
  nw(around:$radius,$latitude,$longitude)["leisure"~"park|sports_centre|fitness_centre|playground"];
  nw(around:$radius,$latitude,$longitude)["shop"~"supermarket|convenience|bakery|clothes"];
);
out center qt $maxResults;
''';

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent},
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode != 200) {
      throw Exception('Overpass API error ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? [];

    var places = elements
        .cast<Map<String, dynamic>>()
        .where((e) {
          final tags = e['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] ?? tags['name:vi'] ?? tags['name:en'];
          return name != null && name.toString().trim().isNotEmpty;
        })
        .expand((e) {
          try {
            return [NearbyPlace.fromOverpassJson(e)];
          } on FormatException catch (error) {
            debugPrint('ExploreApiService: skipping invalid place: $error');
            return <NearbyPlace>[];
          }
        })
        .toList();

    // Enrich places with photos from Wikimedia Commons.
    places = await _enrichWithWikimediaPhotos(
      places,
      latitude,
      longitude,
      radius,
    );

    _cache[cacheKey] = _CacheEntry(DateTime.now(), places);
    _evictCacheIfNeeded();

    debugPrint(
      'ExploreApiService: got ${places.length} nearby places from $url',
    );
    return places;
  }

  /// Text search using Nominatim API.
  Future<List<NearbyPlace>> searchByText({
    required String query,
    required double latitude,
    required double longitude,
    int maxResults = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    final cacheKey =
        '${latitude.toStringAsFixed(3)}_'
        '${longitude.toStringAsFixed(3)}_q_$query';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      return cached.data;
    }

    try {
      final offset = 0.05;
      final uri = Uri.parse(_nominatimUrl).replace(
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': maxResults.toString(),
          'viewbox':
              '${longitude - offset},${latitude + offset},'
              '${longitude + offset},${latitude - offset}',
          'bounded': '0',
          'addressdetails': '1',
          'accept-language': 'vi',
        },
      );

      debugPrint('ExploreApiService: GET Nominatim query="$query"');

      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('ExploreApiService: Nominatim error ${response.statusCode}');
        throw Exception('Nominatim returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final places = decoded
          .cast<Map<String, dynamic>>()
          .where((e) {
            final name = e['display_name'] ?? '';
            return name.toString().trim().isNotEmpty;
          })
          .expand((e) {
            try {
              return [NearbyPlace.fromNominatimJson(e)];
            } on FormatException catch (error) {
              debugPrint('ExploreApiService: skipping invalid place: $error');
              return <NearbyPlace>[];
            }
          })
          .toList();

      _cache[cacheKey] = _CacheEntry(DateTime.now(), places);
      _evictCacheIfNeeded();

      debugPrint('ExploreApiService: text search got ${places.length} results');
      return places;
    } catch (error) {
      debugPrint('ExploreApiService: searchByText failed: $error');
      if (cached != null) return cached.data;
      rethrow;
    }
  }
  // ── Reverse Geocoding ──

  /// Get readable address (city/district) from coordinates via Nominatim
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse')
          .replace(
            queryParameters: {
              'lat': lat.toString(),
              'lon': lng.toString(),
              'format': 'jsonv2',
              'accept-language': 'vi',
            },
          );
      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final address = decoded['address'] as Map<String, dynamic>?;
        if (address != null) {
          final district =
              address['city_district'] ??
              address['suburb'] ??
              address['county'];
          final city = address['city'] ?? address['town'] ?? address['state'];
          if (district != null && city != null) return '$district, $city';
          if (city != null) return city.toString();
          return decoded['display_name']
              ?.toString()
              .split(',')
              .take(2)
              .join(', ');
        }
      }
    } catch (e) {
      debugPrint('ExploreApiService: Reverse geocode failed: $e');
    }
    return null;
  }

  // ── Wikimedia Commons photo enrichment ──

  /// Fetch photos from Wikimedia Commons near the given coordinates,
  /// then assign them to the closest places that don't have photos yet.
  Future<List<NearbyPlace>> _enrichWithWikimediaPhotos(
    List<NearbyPlace> places,
    double centerLat,
    double centerLng,
    double radius,
  ) async {
    // Collect places that need photos (no OSM image tag).
    final needsPhoto = <int>[];
    for (var i = 0; i < places.length; i++) {
      final p = places[i];
      // Places with OSM image/wikimedia_commons tags already have real photos.
      // Others have static map URLs (contain 'staticmap') or null.
      if (p.photoUrl == null ||
          p.photoUrl!.contains('staticmap') ||
          p.photoUrl!.isEmpty) {
        needsPhoto.add(i);
      }
    }

    if (needsPhoto.isEmpty) return places;

    try {
      // Wikimedia Commons geosearch: find images near center.
      final wikiRadius = radius.clamp(100, 10000).toInt();
      final uri = Uri.parse(_wikimediaUrl).replace(
        queryParameters: {
          'action': 'query',
          'generator': 'geosearch',
          'ggsprimary': 'all',
          'ggsnamespace': '6', // File namespace
          'ggsradius': wikiRadius.toString(),
          'ggscoord': '$centerLat|$centerLng',
          'ggslimit': '50',
          'prop': 'imageinfo|coordinates',
          'iiprop': 'url',
          'iiurlwidth': '400',
          'format': 'json',
        },
      );

      debugPrint('ExploreApiService: fetching Wikimedia photos...');

      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return places;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final queryResult = decoded['query'] as Map<String, dynamic>?;
      final pages = queryResult?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return places;

      // Build list of (lat, lng, thumbUrl) from Wikimedia results.
      final wikiPhotos = <_WikiPhoto>[];
      for (final page in pages.values) {
        final pageMap = page as Map<String, dynamic>;
        final imageInfo = pageMap['imageinfo'] as List<dynamic>?;
        final coords = pageMap['coordinates'] as List<dynamic>?;

        if (imageInfo == null || imageInfo.isEmpty) continue;
        if (coords == null || coords.isEmpty) continue;

        final info = imageInfo[0] as Map<String, dynamic>;
        final coord = coords[0] as Map<String, dynamic>;
        final thumbUrl = info['thumburl'] as String?;
        final photoLat = (coord['lat'] as num?)?.toDouble();
        final photoLng = (coord['lon'] as num?)?.toDouble();

        if (thumbUrl != null && photoLat != null && photoLng != null) {
          wikiPhotos.add(_WikiPhoto(photoLat, photoLng, thumbUrl));
        }
      }

      if (wikiPhotos.isEmpty) return places;

      debugPrint(
        'ExploreApiService: found ${wikiPhotos.length} Wikimedia photos',
      );

      // Assign each photo to the closest place that needs one.
      final result = List<NearbyPlace>.from(places);
      final assignedPhotos = <int>{}; // Track used photo indices.

      for (final placeIdx in needsPhoto) {
        final place = result[placeIdx];
        double bestDist = double.infinity;
        int bestPhotoIdx = -1;

        for (var i = 0; i < wikiPhotos.length; i++) {
          if (assignedPhotos.contains(i)) continue;
          final dist = _haversineDistance(
            place.latitude,
            place.longitude,
            wikiPhotos[i].lat,
            wikiPhotos[i].lng,
          );
          if (dist < bestDist && dist < 200) {
            // Max 200m distance
            bestDist = dist;
            bestPhotoIdx = i;
          }
        }

        if (bestPhotoIdx >= 0) {
          result[placeIdx] = place.copyWith(
            photoUrl: wikiPhotos[bestPhotoIdx].url,
          );
          assignedPhotos.add(bestPhotoIdx);
        }
      }

      return result;
    } catch (error) {
      debugPrint('ExploreApiService: Wikimedia photo fetch failed: $error');
      return places; // Non-critical, return places without photos.
    }
  }

  /// Haversine distance in meters between two coordinates.
  static double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;

  void _evictCacheIfNeeded() {
    if (_cache.length <= _maxCacheEntries) return;
    final sortedKeys = _cache.keys.toList()
      ..sort((a, b) => _cache[a]!.timestamp.compareTo(_cache[b]!.timestamp));
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(sortedKeys.removeAt(0));
    }
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  const _CacheEntry(this.timestamp, this.data);
  final DateTime timestamp;
  final List<NearbyPlace> data;
}

class _WikiPhoto {
  const _WikiPhoto(this.lat, this.lng, this.url);
  final double lat;
  final double lng;
  final String url;
}
