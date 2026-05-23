import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/category.dart';
import 'telemetry_service.dart';

class CategoryService {
  CategoryService(this._apiClient, [this._telemetryService]);

  final ApiClient _apiClient;
  final TelemetryService? _telemetryService;

  Future<List<Category>> getCategories() async {
    final data = await _apiClient.get(ApiEndpoints.categories);
    return (data as List<dynamic>)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.categories, data);
      final category = Category.fromJson(response as Map<String, dynamic>);
      _telemetryService?.track(
        type: 'category',
        action: 'create',
        resourceType: 'category',
        resourceId: category.id,
        screen: 'add_place',
        metadata: {'name': category.name},
      );
      return category;
    } catch (error) {
      _telemetryService?.track(
        type: 'category',
        action: 'create_failed',
        resourceType: 'category',
        screen: 'add_place',
        severity: 'WARN',
        message: error.toString(),
        metadata: {'name': data['name']},
      );
      rethrow;
    }
  }
}
