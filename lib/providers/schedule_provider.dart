import 'package:flutter/foundation.dart';

import '../models/schedule.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';

class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider(this._scheduleService, this._notificationService);

  final ScheduleService _scheduleService;
  final NotificationGateway _notificationService;

  final List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _pendingSyncCount = 0;
  DateTime? _activeDateFilter;

  List<Schedule> get schedules => List.unmodifiable(_schedules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPendingSync => _pendingSyncCount > 0;

  void clear() {
    _schedules.clear();
    _isLoading = false;
    _errorMessage = null;
    _pendingSyncCount = 0;
    _activeDateFilter = null;
    notifyListeners();
  }

  Future<void> fetchSchedules() async {
    _activeDateFilter = null;
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

  Future<List<Schedule>> getSchedulesSnapshot({DateTime? date}) {
    if (date == null) {
      return _scheduleService.getSchedules();
    }
    return _scheduleService.getSchedulesByDate(date);
  }

  Future<void> resyncUpcomingNotifications() async {
    try {
      final schedules = await _scheduleService.getSchedules();
      final now = DateTime.now();

      for (final schedule in schedules) {
        if (schedule.hasReminder &&
            schedule.status == scheduleStatusUpcoming &&
            shouldScheduleReminderAt(
              visitDateTimeForSchedule(schedule),
              now: now,
            )) {
          await _scheduleNotification(schedule);
        }
      }
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> fetchByDate(DateTime date) async {
    _activeDateFilter = _dateOnly(date);
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
    final optimistic = _buildOptimisticSchedule(
      data,
      id: _temporaryScheduleId(),
      isPendingSync: true,
    );
    final shouldShowOptimistic = _matchesActiveFilter(optimistic);

    _pendingSyncCount += 1;
    _errorMessage = null;
    if (shouldShowOptimistic) {
      _upsertVisibleSchedule(optimistic);
    }
    notifyListeners();

    await _safelyApplyNotificationState(optimistic);
    try {
      final schedule = await _scheduleService.createSchedule(data);
      await _safelyClearNotificationState(optimistic.id);
      await _safelyApplyNotificationState(schedule);

      if (shouldShowOptimistic) {
        _removeScheduleById(optimistic.id);
      }
      if (_matchesActiveFilter(schedule)) {
        _upsertVisibleSchedule(schedule);
      }
      _errorMessage = null;
      return schedule;
    } catch (error) {
      await _safelyClearNotificationState(optimistic.id);
      if (shouldShowOptimistic) {
        _removeScheduleById(optimistic.id);
      }
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _decrementPendingSync();
      notifyListeners();
    }
  }

  Future<void> updateSchedule(
    String id,
    Map<String, dynamic> data, {
    Schedule? currentSchedule,
  }) async {
    final previousVisibleIndex = _schedules.indexWhere(
      (schedule) => schedule.id == id,
    );
    final previous =
        currentSchedule ??
        (previousVisibleIndex == -1 ? null : _schedules[previousVisibleIndex]);

    _pendingSyncCount += 1;
    _errorMessage = null;

    Schedule? optimistic;
    if (previous != null) {
      optimistic = _mergeSchedule(previous, data).copyWith(isPendingSync: true);
      _applyVisibleMutation(optimistic, fallbackId: id);
    }
    notifyListeners();
    if (optimistic != null) {
      await _safelyApplyNotificationState(optimistic);
    }

    try {
      final updated = await _scheduleService.updateSchedule(id, data);
      await _safelyApplyNotificationState(updated);
      _applyVisibleMutation(updated, fallbackId: id);

      _errorMessage = null;
    } catch (error) {
      if (previous != null) {
        await _safelyApplyNotificationState(previous);
        _restoreVisibleSchedule(previous, previousVisibleIndex);
      }
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _decrementPendingSync();
      notifyListeners();
    }
  }

  Future<void> updateScheduleStatus(
    String id,
    String status, {
    Schedule? currentSchedule,
  }) async {
    final existing = currentSchedule ?? _visibleScheduleById(id);
    if (existing != null && existing.status == status) {
      return;
    }

    await updateSchedule(id, {'status': status}, currentSchedule: existing);
  }

  Future<void> deleteSchedule(String id, {Schedule? schedule}) async {
    final previousVisibleIndex = _schedules.indexWhere(
      (existing) => existing.id == id,
    );
    final previous =
        schedule ??
        (previousVisibleIndex == -1 ? null : _schedules[previousVisibleIndex]);

    _pendingSyncCount += 1;
    _errorMessage = null;
    if (previous != null) {
      _removeScheduleById(id);
    }
    notifyListeners();

    await _safelyClearNotificationState(id);
    try {
      await _scheduleService.deleteSchedule(id);
      _errorMessage = null;
    } catch (error) {
      if (previous != null) {
        _restoreVisibleSchedule(previous, previousVisibleIndex);
        await _safelyApplyNotificationState(previous);
      }
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _decrementPendingSync();
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _applyVisibleMutation(Schedule schedule, {String? fallbackId}) {
    final targetId = fallbackId ?? schedule.id;
    _removeScheduleById(targetId);
    if (_matchesActiveFilter(schedule)) {
      _upsertVisibleSchedule(schedule);
    }
  }

  void _restoreVisibleSchedule(Schedule schedule, int previousVisibleIndex) {
    if (!_matchesActiveFilter(schedule)) {
      _removeScheduleById(schedule.id);
      return;
    }

    _removeScheduleById(schedule.id);
    if (previousVisibleIndex >= 0 &&
        previousVisibleIndex <= _schedules.length) {
      _schedules.insert(previousVisibleIndex, schedule);
      return;
    }
    _upsertVisibleSchedule(schedule);
  }

  void _upsertVisibleSchedule(Schedule schedule) {
    final existingIndex = _schedules.indexWhere(
      (item) => item.id == schedule.id,
    );
    if (existingIndex != -1) {
      _schedules.removeAt(existingIndex);
    }

    final insertIndex = _schedules.indexWhere(
      (item) => _compareSchedules(schedule, item) < 0,
    );

    if (insertIndex == -1) {
      _schedules.add(schedule);
    } else {
      _schedules.insert(insertIndex, schedule);
    }
  }

  void _removeScheduleById(String id) {
    _schedules.removeWhere((schedule) => schedule.id == id);
  }

  Schedule? _visibleScheduleById(String id) {
    final index = _schedules.indexWhere((schedule) => schedule.id == id);
    if (index == -1) {
      return null;
    }
    return _schedules[index];
  }

  bool _matchesActiveFilter(Schedule schedule) {
    final filter = _activeDateFilter;
    if (filter == null) {
      return true;
    }

    return _sameDay(schedule.date, filter);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Schedule _buildOptimisticSchedule(
    Map<String, dynamic> data, {
    required String id,
    required bool isPendingSync,
  }) {
    return Schedule(
      id: id,
      placeId: _asNullableString(data['placeId']),
      title: _asNullableString(data['title']),
      note: _asNullableString(data['note']),
      date: _parseScheduleDate(data['date']) ?? DateTime.now(),
      time: (data['time'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim().isNotEmpty == true
          ? (data['status'] as String).trim()
          : scheduleStatusUpcoming,
      hasReminder: data['hasReminder'] as bool? ?? false,
      placeName: _asNullableString(data['placeName']),
      category: _asNullableString(data['category']),
      address: _asNullableString(data['address']),
      openingHours: _asNullableString(data['openingHours']),
      mapsUrl: _asNullableString(data['mapsUrl']),
      latitude: _asNullableDouble(data['latitude']),
      longitude: _asNullableDouble(data['longitude']),
      isPendingSync: isPendingSync,
    );
  }

  Schedule _mergeSchedule(Schedule schedule, Map<String, dynamic> data) {
    return schedule.copyWith(
      placeId: (data['placeId'] as String?) ?? schedule.placeId,
      title: data.containsKey('title')
          ? _asNullableString(data['title'])
          : schedule.title,
      note: data.containsKey('note')
          ? _asNullableString(data['note'])
          : schedule.note,
      date: data.containsKey('date')
          ? _parseScheduleDate(data['date']) ?? schedule.date
          : schedule.date,
      time: (data['time'] as String?)?.trim() ?? schedule.time,
      status: (data['status'] as String?)?.trim().isNotEmpty == true
          ? (data['status'] as String).trim()
          : schedule.status,
      hasReminder: data['hasReminder'] as bool? ?? schedule.hasReminder,
      placeName: data.containsKey('placeName')
          ? _asNullableString(data['placeName'])
          : schedule.placeName,
      category: data.containsKey('category')
          ? _asNullableString(data['category'])
          : schedule.category,
      address: data.containsKey('address')
          ? _asNullableString(data['address'])
          : schedule.address,
      openingHours: data.containsKey('openingHours')
          ? _asNullableString(data['openingHours'])
          : schedule.openingHours,
      mapsUrl: data.containsKey('mapsUrl')
          ? _asNullableString(data['mapsUrl'])
          : schedule.mapsUrl,
      latitude: data.containsKey('latitude')
          ? _asNullableDouble(data['latitude'])
          : schedule.latitude,
      longitude: data.containsKey('longitude')
          ? _asNullableDouble(data['longitude'])
          : schedule.longitude,
    );
  }

  DateTime? _parseScheduleDate(Object? value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    return null;
  }

  String _temporaryScheduleId() {
    return 'local-schedule-${DateTime.now().microsecondsSinceEpoch}';
  }

  int _compareSchedules(Schedule a, Schedule b) {
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) {
      return dateCompare;
    }

    final timeCompare = a.time.compareTo(b.time);
    if (timeCompare != 0) {
      return timeCompare;
    }

    return a.id.compareTo(b.id);
  }

  void _decrementPendingSync() {
    if (_pendingSyncCount > 0) {
      _pendingSyncCount -= 1;
    }
  }

  Future<void> _scheduleNotification(Schedule schedule) async {
    final now = DateTime.now();
    final visitDateTime = visitDateTimeForSchedule(schedule);

    final exactId = _notificationIdFromScheduleId('${schedule.id}_exact');
    await _notificationService.cancelNotification(exactId);

    if (shouldScheduleReminderAt(visitDateTime, now: now)) {
      await _notificationService.scheduleNotification(
        visitDateTime,
        'Đến giờ đi ${schedule.displayPlaceName} rồi!',
        'Đã đến giờ theo lịch trình của bạn. Chúc bạn vui vẻ!',
        id: exactId,
      );
    }

    final reminderDateTime = advanceReminderDateTimeForSchedule(schedule);

    final advanceId = _notificationIdFromScheduleId('${schedule.id}_advance');
    await _notificationService.cancelNotification(advanceId);

    if (shouldScheduleReminderAt(reminderDateTime, now: now)) {
      await _notificationService.scheduleNotification(
        reminderDateTime,
        'Sắp đến giờ đi ${schedule.displayPlaceName}',
        'Bạn có lịch đến ${schedule.displayPlaceName} lúc ${schedule.time}.',
        id: advanceId,
      );
    }
  }

  Future<void> _clearNotificationState(String scheduleId) async {
    await _notificationService.cancelNotification(
      _notificationIdFromScheduleId('${scheduleId}_advance'),
    );
    await _notificationService.cancelNotification(
      _notificationIdFromScheduleId('${scheduleId}_exact'),
    );
  }

  Future<void> _applyNotificationState(Schedule schedule) async {
    if (schedule.hasReminder && schedule.status == scheduleStatusUpcoming) {
      await _scheduleNotification(schedule);
      return;
    }

    await _clearNotificationState(schedule.id);
  }

  Future<void> _safelyClearNotificationState(String scheduleId) async {
    try {
      await _clearNotificationState(scheduleId);
    } catch (error) {
      debugPrint('Failed to clear schedule notifications: $error');
    }
  }

  Future<void> _safelyApplyNotificationState(Schedule schedule) async {
    try {
      await _applyNotificationState(schedule);
    } catch (error) {
      debugPrint('Failed to sync schedule notifications: $error');
    }
  }

  String? _asNullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _asNullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}

DateTime visitDateTimeForSchedule(Schedule schedule) {
  final startTime = schedule.time.split('-').first.trim();
  final parts = startTime.split(':');
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

DateTime advanceReminderDateTimeForSchedule(Schedule schedule) {
  return visitDateTimeForSchedule(
    schedule,
  ).subtract(const Duration(minutes: 30));
}

bool shouldScheduleReminderAt(DateTime scheduledAt, {DateTime? now}) {
  return scheduledAt.isAfter(now ?? DateTime.now());
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _notificationIdFromScheduleId(String scheduleId) {
  var hash = 0;
  for (final codeUnit in scheduleId.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
