import 'package:flutter/foundation.dart';

import '../models/place.dart';
import '../services/place_service.dart';

class PlaceProvider extends ChangeNotifier {
  PlaceProvider(this._placeService);

  final PlaceService _placeService;

  final List<Place> _places = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Place> get places => List.unmodifiable(_places);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
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
    _setLoading(true);
    try {
      final place = await _placeService.createPlace(data);
      _places.insert(0, place);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updatePlace(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      final updated = await _placeService.updatePlace(id, data);
      final index = _places.indexWhere((place) => place.id == id);
      if (index != -1) {
        _places[index] = updated;
      }
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deletePlace(String id) async {
    _setLoading(true);
    try {
      await _placeService.deletePlace(id);
      _places.removeWhere((place) => place.id == id);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
