import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/place.dart';

class PlaceService {
  PlaceService(this._apiClient);

  final ApiClient _apiClient;

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
    final response = await _apiClient.post(ApiEndpoints.places, data);
    return Place.fromJson(response as Map<String, dynamic>);
  }

  Future<Place> updatePlace(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.patch(ApiEndpoints.placeById(id), data);
    return Place.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deletePlace(String id) async {
    await _apiClient.delete(ApiEndpoints.placeById(id));
  }
}
