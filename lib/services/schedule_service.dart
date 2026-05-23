import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/schedule.dart';
import 'telemetry_service.dart';

class ScheduleService {
  ScheduleService(this._apiClient, [this._telemetryService]);

  final ApiClient _apiClient;
  final TelemetryService? _telemetryService;

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
    try {
      final response = await _apiClient.post(
        ApiEndpoints.schedules,
        _apiPayload(data),
      );
      final schedule = Schedule.fromJson(response as Map<String, dynamic>);
      _track('create', schedule);
      return schedule;
    } catch (error) {
      _trackFailure('create', error, data);
      rethrow;
    }
  }

  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.scheduleById(id),
        _apiPayload(data),
      );
      final schedule = Schedule.fromJson(response as Map<String, dynamic>);
      _track('update', schedule);
      return schedule;
    } catch (error) {
      _trackFailure('update', error, data, resourceId: id);
      rethrow;
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _apiClient.delete(ApiEndpoints.scheduleById(id));
      _telemetryService?.track(
        type: 'schedule',
        action: 'delete',
        resourceType: 'schedule',
        resourceId: id,
        screen: 'schedule',
      );
    } catch (error) {
      _trackFailure('delete', error, const {}, resourceId: id);
      rethrow;
    }
  }

  void _track(String action, Schedule schedule) {
    _telemetryService?.track(
      type: 'schedule',
      action: action,
      resourceType: 'schedule',
      resourceId: schedule.id,
      screen: 'schedule',
      metadata: {
        'placeId': schedule.placeId,
        'date': schedule.date.toIso8601String(),
        'time': schedule.time,
      },
    );
  }

  void _trackFailure(
    String action,
    Object error,
    Map<String, dynamic> data, {
    String? resourceId,
  }) {
    _telemetryService?.track(
      type: 'schedule',
      action: '${action}_failed',
      resourceType: 'schedule',
      resourceId: resourceId,
      screen: 'schedule',
      message: error.toString(),
      severity: 'WARN',
      metadata: {
        'placeId': data['placeId'],
        'date': data['date'],
        'time': data['time'],
      },
    );
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
