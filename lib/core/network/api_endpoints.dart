import 'dart:io' show Platform;

class ApiEndpoints {
  const ApiEndpoints._();

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    return 'https://roamy-production.up.railway.app/api/v1';
  }

  static const categories = '/categories';
  static const places = '/places';
  static const schedules = '/schedules';

  static String placeById(String id) => '$places/$id';
  static String scheduleById(String id) => '$schedules/$id';
}
