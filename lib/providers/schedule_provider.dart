import 'package:flutter/foundation.dart';

import '../models/schedule.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';

class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider(this._scheduleService, this._notificationService);

  final ScheduleService _scheduleService;
  final NotificationService _notificationService;

  final List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Schedule> get schedules => List.unmodifiable(_schedules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSchedules() async {
    _setLoading(true);
    try {
      final schedules = await _scheduleService.getSchedules();
      _schedules
        ..clear()
        ..addAll(schedules);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resyncUpcomingNotifications() async {
    try {
      final schedules = await _scheduleService.getSchedules();
      final now = DateTime.now();

      for (final schedule in schedules) {
        if (schedule.hasReminder &&
            schedule.status == 'UPCOMING' &&
            _visitDateTime(schedule).isAfter(now)) {
          await _scheduleNotification(schedule);
        }
      }
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> fetchByDate(DateTime date) async {
    _setLoading(true);
    try {
      final schedules = await _scheduleService.getSchedulesByDate(date);
      _schedules
        ..clear()
        ..addAll(schedules);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      final schedule = await _scheduleService.createSchedule(data);
      _schedules.add(schedule);
      if (schedule.hasReminder) {
        await _scheduleNotification(schedule);
      }
      _errorMessage = null;
      return schedule;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      final updated = await _scheduleService.updateSchedule(id, data);
      final index = _schedules.indexWhere((schedule) => schedule.id == id);
      if (index != -1) {
        _schedules[index] = updated;
      }

      if (updated.hasReminder && updated.status == 'UPCOMING') {
        await _scheduleNotification(updated);
      } else {
        await _notificationService.cancelNotification(
          _notificationIdFromScheduleId('${updated.id}_advance'),
        );
        await _notificationService.cancelNotification(
          _notificationIdFromScheduleId('${updated.id}_exact'),
        );
      }

      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteSchedule(String id) async {
    _setLoading(true);
    try {
      await _scheduleService.deleteSchedule(id);
      await _notificationService.cancelNotification(
        _notificationIdFromScheduleId('${id}_advance'),
      );
      await _notificationService.cancelNotification(
        _notificationIdFromScheduleId('${id}_exact'),
      );
      _schedules.removeWhere((schedule) => schedule.id == id);
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

  Future<void> _scheduleNotification(Schedule schedule) async {
    final visitDateTime = _visitDateTime(schedule);
    final reminderDateTime = visitDateTime.subtract(
      const Duration(minutes: 30),
    );
    await _notificationService.scheduleNotification(
      reminderDateTime,
      'Sắp đến giờ đi ${schedule.displayPlaceName}',
      'Bạn có lịch đến ${schedule.displayPlaceName} lúc ${schedule.time}.',
      id: _notificationIdFromScheduleId('${schedule.id}_advance'),
    );
    await _notificationService.scheduleNotification(
      visitDateTime,
      'Đến giờ đi ${schedule.displayPlaceName} rồi!',
      'Đã đến giờ theo lịch trình của bạn. Chúc bạn vui vẻ!',
      id: _notificationIdFromScheduleId('${schedule.id}_exact'),
    );
  }
}

DateTime _visitDateTime(Schedule schedule) {
  final parts = schedule.time.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(
    schedule.date.year,
    schedule.date.month,
    schedule.date.day,
    hour,
    minute,
  );
}

int _notificationIdFromScheduleId(String scheduleId) {
  var hash = 0;
  for (final codeUnit in scheduleId.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
