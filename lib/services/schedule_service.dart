import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/schedule.dart';

class ScheduleService {
  ScheduleService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Schedule>> getSchedules() async {
    final data = await _apiClient.get(ApiEndpoints.schedules);
    return (data as List<dynamic>)
        .map((item) => Schedule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Schedule>> getSchedulesByDate(DateTime date) async {
    final data = await _apiClient.get(
      ApiEndpoints.schedules,
      query: {'date': _dateToApi(date)},
    );
    return (data as List<dynamic>)
        .map((item) => Schedule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiEndpoints.schedules, data);
    return Schedule.fromJson(response as Map<String, dynamic>);
  }

  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.patch(
      ApiEndpoints.scheduleById(id),
      data,
    );
    return Schedule.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String id) async {
    await _apiClient.delete(ApiEndpoints.scheduleById(id));
  }
}

String _dateToApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
