import 'dart:io' show Platform;

class ApiEndpoints {
  const ApiEndpoints._();

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:4000/api/v1';
      }
    } catch (_) {}

    return 'http://localhost:4000/api/v1';
  }

  static const categories = '/categories';
  static const places = '/places';
  static const schedules = '/schedules';

  static String placeById(String id) => '$places/$id';
  static String scheduleById(String id) => '$schedules/$id';
}
