import 'package:flutter/foundation.dart';

import '../models/place.dart';
import '../services/place_service.dart';

class PlaceProvider extends ChangeNotifier {
  PlaceProvider(this._placeService);

  final PlaceService _placeService;

  final List<Place> _places = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _pendingSyncCount = 0;

  List<Place> get places => List.unmodifiable(_places);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPendingSync => _pendingSyncCount > 0;
  bool get isEmpty => _places.isEmpty && !_isLoading && _errorMessage == null;

  Future<void> fetchPlaces({String? categoryId}) async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      final places = await _placeService.getPlaces(categoryId: categoryId);
      _places
        ..clear()
        ..addAll(places);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Place> getPlaceById(String id) {
    return _placeService.getPlaceById(id);
  }

  Future<void> addPlace(Map<String, dynamic> data) async {
    final optimisticPlace = _buildOptimisticPlace(
      data,
      id: _temporaryPlaceId(),
      isPendingSync: true,
    );
    _pendingSyncCount += 1;
    _errorMessage = null;
    _places.insert(0, optimisticPlace);
    notifyListeners();

    try {
      final place = await _placeService.createPlace(data);
      final index = _places.indexWhere((item) => item.id == optimisticPlace.id);
      if (index == -1) {
        _places.insert(0, place);
      } else {
        _places[index] = place;
      }
      _errorMessage = null;
    } catch (error) {
      _places.removeWhere((item) => item.id == optimisticPlace.id);
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _decrementPendingSync();
      notifyListeners();
    }
  }

  Future<void> updatePlace(String id, Map<String, dynamic> data) async {
    final index = _places.indexWhere((place) => place.id == id);
    final previous = index == -1 ? null : _places[index];

    if (previous != null) {
      _pendingSyncCount += 1;
      _errorMessage = null;
      _places[index] = _mergePlace(
        previous,
        data,
      ).copyWith(isPendingSync: true);
      notifyListeners();
    }

    try {
      final updated = await _placeService.updatePlace(id, data);
      final updatedIndex = _places.indexWhere((place) => place.id == id);
      if (updatedIndex != -1) {
        _places[updatedIndex] = updated;
      }
      _errorMessage = null;
    } catch (error) {
      if (previous != null) {
        final rollbackIndex = _places.indexWhere((place) => place.id == id);
        if (rollbackIndex == -1) {
          _places.insert(index, previous);
        } else {
          _places[rollbackIndex] = previous;
        }
      }
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (previous != null) {
        _decrementPendingSync();
        notifyListeners();
      }
    }
  }

  Future<void> deletePlace(String id) async {
    final index = _places.indexWhere((place) => place.id == id);
    final removed = index == -1 ? null : _places.removeAt(index);
    if (removed != null) {
      _pendingSyncCount += 1;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _placeService.deletePlace(id);
      _errorMessage = null;
    } catch (error) {
      if (removed != null) {
        final insertIndex = index.clamp(0, _places.length);
        _places.insert(insertIndex, removed);
      }
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (removed != null) {
        _decrementPendingSync();
        notifyListeners();
      }
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _temporaryPlaceId() {
    return 'local-${DateTime.now().microsecondsSinceEpoch}';
  }

  Place _buildOptimisticPlace(
    Map<String, dynamic> data, {
    required String id,
    required bool isPendingSync,
  }) {
    return Place(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      categoryId: (data['categoryId'] as String?) ?? '',
      address: (data['address'] as String?)?.trim() ?? '',
      priceRange: (data['priceRange'] as String?)?.trim() ?? '',
      openingHours: (data['openingHours'] as String?)?.trim() ?? '',
      phone: _asNullableString(data['phone']),
      mapsUrl: _asNullableString(data['mapsUrl']),
      note: _asNullableString(data['note']),
      imageUrl: _asNullableString(data['imageUrl']),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      hasReminder: data['hasReminder'] as bool? ?? false,
      categoryName: _asNullableString(data['categoryName']),
      latitude: _asNullableDouble(data['latitude']),
      longitude: _asNullableDouble(data['longitude']),
      isPendingSync: isPendingSync,
    );
  }

  Place _mergePlace(Place place, Map<String, dynamic> data) {
    return place.copyWith(
      name: (data['name'] as String?)?.trim() ?? place.name,
      categoryId: (data['categoryId'] as String?) ?? place.categoryId,
      address: (data['address'] as String?)?.trim() ?? place.address,
      priceRange: (data['priceRange'] as String?)?.trim() ?? place.priceRange,
      openingHours:
          (data['openingHours'] as String?)?.trim() ?? place.openingHours,
      phone: data.containsKey('phone')
          ? _asNullableString(data['phone'])
          : place.phone,
      mapsUrl: data.containsKey('mapsUrl')
          ? _asNullableString(data['mapsUrl'])
          : place.mapsUrl,
      note: data.containsKey('note')
          ? _asNullableString(data['note'])
          : place.note,
      imageUrl: data.containsKey('imageUrl')
          ? _asNullableString(data['imageUrl'])
          : place.imageUrl,
      rating: (data['rating'] as num?)?.toDouble() ?? place.rating,
      hasReminder: data['hasReminder'] as bool? ?? place.hasReminder,
      categoryName: data.containsKey('categoryName')
          ? _asNullableString(data['categoryName'])
          : place.categoryName,
      latitude: data.containsKey('latitude')
          ? _asNullableDouble(data['latitude'])
          : place.latitude,
      longitude: data.containsKey('longitude')
          ? _asNullableDouble(data['longitude'])
          : place.longitude,
    );
  }

  String? _asNullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _asNullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  void _decrementPendingSync() {
    if (_pendingSyncCount > 0) {
      _pendingSyncCount -= 1;
    }
  }
}
