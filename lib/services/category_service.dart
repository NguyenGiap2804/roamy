import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/category.dart';

class CategoryService {
  CategoryService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Category>> getCategories() async {
    final data = await _apiClient.get(ApiEndpoints.categories);
    return (data as List<dynamic>)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiEndpoints.categories, data);
    return Category.fromJson(response as Map<String, dynamic>);
  }
}
