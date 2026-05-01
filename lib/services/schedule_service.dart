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
    final response = await _apiClient.post(
      ApiEndpoints.schedules,
      _apiPayload(data),
    );
    return Schedule.fromJson(response as Map<String, dynamic>);
  }

  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.patch(
      ApiEndpoints.scheduleById(id),
      _apiPayload(data),
    );
    return Schedule.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String id) async {
    await _apiClient.delete(ApiEndpoints.scheduleById(id));
  }
}

Map<String, dynamic> _apiPayload(Map<String, dynamic> data) {
  return {
    if (data.containsKey('placeId')) 'placeId': data['placeId'],
    if (data.containsKey('date')) 'date': data['date'],
    if (data.containsKey('time')) 'time': data['time'],
    if (data.containsKey('status')) 'status': data['status'],
    if (data.containsKey('hasReminder')) 'hasReminder': data['hasReminder'],
  };
}

String _dateToApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
