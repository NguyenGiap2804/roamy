import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/place.dart';
import 'telemetry_service.dart';

class PlaceService {
  PlaceService(this._apiClient, [this._telemetryService]);

  final ApiClient _apiClient;
  final TelemetryService? _telemetryService;

  Future<List<Place>> getPlaces({String? categoryId}) async {
    final data = await _apiClient.get(
      ApiEndpoints.places,
      query: categoryId == null ? null : {'categoryId': categoryId},
    );
    return (data as List<dynamic>)
        .map((item) => Place.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Place>> getPopularPlaces({int limit = 5}) async {
    final data = await _apiClient.get(
      ApiEndpoints.places,
      query: {'sort': 'rating', 'limit': '$limit'},
    );
    return (data as List<dynamic>)
        .map((item) => Place.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Place> getPlaceById(String id) async {
    final data = await _apiClient.get(ApiEndpoints.placeById(id));
    return Place.fromJson(data as Map<String, dynamic>);
  }

  Future<Place> createPlace(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.places, data);
      final place = Place.fromJson(response as Map<String, dynamic>);
      _track('create', place, metadata: {'name': place.name});
      return place;
    } catch (error) {
      _trackFailure('create', error, data);
      rethrow;
    }
  }

  Future<Place> updatePlace(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.patch(ApiEndpoints.placeById(id), data);
      final place = Place.fromJson(response as Map<String, dynamic>);
      _track('update', place, metadata: {'changedFields': data.keys.toList()});
      return place;
    } catch (error) {
      _trackFailure('update', error, data, resourceId: id);
      rethrow;
    }
  }

  Future<void> deletePlace(String id) async {
    try {
      await _apiClient.delete(ApiEndpoints.placeById(id));
      _telemetryService?.track(
        type: 'place',
        action: 'delete',
        resourceType: 'place',
        resourceId: id,
        screen: 'saved_places',
      );
    } catch (error) {
      _trackFailure('delete', error, const {}, resourceId: id);
      rethrow;
    }
  }

  void _track(String action, Place place, {Map<String, Object?>? metadata}) {
    _telemetryService?.track(
      type: 'place',
      action: action,
      resourceType: 'place',
      resourceId: place.id,
      screen: 'add_place',
      message: '${action}_place_success',
      metadata: metadata,
    );
  }

  void _trackFailure(
    String action,
    Object error,
    Map<String, dynamic> data, {
    String? resourceId,
  }) {
    _telemetryService?.track(
      type: 'place',
      action: '${action}_failed',
      resourceType: 'place',
      resourceId: resourceId,
      screen: 'add_place',
      message: error.toString(),
      severity: 'WARN',
      metadata: {
        'name': data['name'],
        'mapsUrl': data['mapsUrl'],
      },
    );
  }
}
