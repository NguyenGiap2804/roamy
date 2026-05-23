import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/nearby_place.dart';
import '../services/google_places_service.dart';
import '../services/location_service.dart';

/// State management for the Explore tab (real-world nearby places).
///
/// Manages:
/// - User location (GPS or fallback)
/// - Nearby places from Overpass API
/// - Category filtering (client-side)
/// - Popular places (sorted by rating)
/// - Text search with debounce via Nominatim
class ExploreProvider extends ChangeNotifier {
  ExploreProvider(this._apiService, this._locationService);

  final ExploreApiService _apiService;
  final LocationService _locationService;

  List<NearbyPlace> _allNearbyPlaces = [];
  List<NearbyPlace> _searchResults = [];
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  bool _initialLoadDone = false;
  String _currentAddress = '';
  Timer? _debounce;
  DateTime? _lastLocationRefreshAt;

  // ── Getters ──

  // Helper to sort places by distance, category priority and data completeness
  List<NearbyPlace> _sortPlacesByPriority(List<NearbyPlace> places) {
    if (_latitude == null || _longitude == null) return places;

    double calculateDistance(double lat2, double lon2) {
      const p = 0.017453292519943295;
      final a =
          0.5 -
          cos((lat2 - _latitude!) * p) / 2 +
          cos(_latitude! * p) *
              cos(lat2 * p) *
              (1 - cos((lon2 - _longitude!) * p)) /
              2;
      return 12742 * asin(sqrt(a)); // Distance in km
    }

    int getCategoryPriority(String cat) {
      if (cat == 'Cafe') return 10;
      if (cat == 'Nhà hàng') return 2;
      if (cat == 'Khách sạn') return 1;
      return 0;
    }

    final sorted = List.of(places);
    sorted.sort((a, b) {
      final distA = calculateDistance(a.latitude, a.longitude);
      final distB = calculateDistance(b.latitude, b.longitude);

      final pA = getCategoryPriority(a.categoryBase);
      final pB = getCategoryPriority(b.categoryBase);

      // If one is very close (< 500m) and the other is far (> 2km),
      // proximity wins regardless of category.
      if (distA < 0.5 && distB > 2.0) return -1;
      if (distB < 0.5 && distA > 2.0) return 1;

      // Otherwise, prioritize by category
      if (pA != pB) return pB.compareTo(pA);

      // Same priority, sort by distance
      return distA.compareTo(distB);
    });
    return sorted;
  }

  /// Nearby places filtered by selected category and sorted by priority.
  List<NearbyPlace> get nearbyPlaces {
    final list = _selectedCategory == 'Tất cả'
        ? _allNearbyPlaces
        : _allNearbyPlaces
              .where((p) => p.categoryBase == _selectedCategory)
              .toList();

    return _sortPlacesByPriority(list);
  }

  /// Popular = top 10 places, strictly prioritizing Cafe > Nhà hàng > Khách sạn,
  /// then falling back to data completeness rating for ties.
  List<NearbyPlace> get popularPlaces {
    final sorted = _sortPlacesByPriority(_allNearbyPlaces);
    return sorted.take(10).toList();
  }

  /// Available categories derived from loaded data.
  List<String> get availableCategories {
    final cats = _allNearbyPlaces.map((p) => p.categoryBase).toSet().toList()
      ..sort();
    return ['Tất cả', ...cats];
  }

  String get selectedCategory => _selectedCategory;
  List<NearbyPlace> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  bool get initialLoadDone => _initialLoadDone;
  String get cityName =>
      _currentAddress.isNotEmpty ? _currentAddress : _locationService.cityName;
  bool get isUsingFallbackLocation => _locationService.isFallback;
  bool get hasSearchQuery => _searchQuery.trim().isNotEmpty;

  // ── Public methods ──

  /// Fetch nearby places (all types). Gets GPS first, then calls API.
  Future<void> fetchNearby() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loc = await _locationService.getCurrentLocation();
      _latitude = loc.latitude;
      _longitude = loc.longitude;
      _lastLocationRefreshAt = DateTime.now();

      final places = await _apiService.searchNearby(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );

      // Async fetch actual street/city name for UI.
      _apiService.reverseGeocode(loc.latitude, loc.longitude).then((addr) {
        if (addr != null && addr.isNotEmpty) {
          _currentAddress = addr;
          notifyListeners();
        }
      });

      _allNearbyPlaces = places;
      _initialLoadDone = true;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Không thể tải địa điểm gần bạn';
      debugPrint('ExploreProvider: fetchNearby failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change category filter (client-side, instant).
  void changeCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Search by text query (debounced 500ms).
  void search(String query) {
    _searchQuery = query;
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(query.trim());
    });
    notifyListeners();
  }

  /// Clear search and go back to nearby view.
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearching = false;
    _debounce?.cancel();
    notifyListeners();
  }

  /// Force-refresh by clearing caches.
  Future<void> refresh() async {
    _locationService.invalidateCache();
    _apiService.clearCache();
    _searchResults = [];
    _searchQuery = '';
    _selectedCategory = 'Tất cả';
    _isSearching = false;
    await fetchNearby();
  }

  Future<void> refreshLocationIfStale({
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    if (_isLoading) return;

    final lastRefresh = _lastLocationRefreshAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < maxAge) {
      return;
    }

    await refresh();
  }

  /// Reverse-geocode a coordinate pair to a human-readable address.
  /// Used by the detail sheet to lazily fill in addresses missing from OSM.
  Future<String?> reverseGeocodePlace(double lat, double lng) {
    return _apiService.reverseGeocode(lat, lng);
  }

  /// Get formatted distance string to a place.
  String getDistanceString(NearbyPlace place) {
    if (_latitude == null || _longitude == null) return '';

    double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
    ) {
      const p = 0.017453292519943295;
      final a =
          0.5 -
          cos((lat2 - lat1) * p) / 2 +
          cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
      return 12742 * asin(sqrt(a));
    }

    final km = calculateDistance(
      _latitude!,
      _longitude!,
      place.latitude,
      place.longitude,
    );
    if (km < 1) return '${(km * 1000).toInt()}m';
    return '${km.toStringAsFixed(1)}km';
  }

  // ── Private ──

  Future<void> _executeSearch(String query) async {
    if (_latitude == null || _longitude == null) return;

    _isSearching = true;
    notifyListeners();

    try {
      final results = await _apiService.searchByText(
        query: query,
        latitude: _latitude!,
        longitude: _longitude!,
      );
      if (_searchQuery.trim() == query) {
        _searchResults = results;
      }
    } catch (error) {
      debugPrint('ExploreProvider: search failed: $error');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
