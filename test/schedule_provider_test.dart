import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/schedule.dart';
import 'package:roamy/providers/schedule_provider.dart';
import 'package:roamy/services/notification_service.dart';
import 'package:roamy/services/schedule_service.dart';

void main() {
  test(
    'createSchedule inserts an optimistic schedule before backend sync finishes',
    () async {
      final createCompleter = Completer<Schedule>();
      final notificationGateway = _FakeNotificationGateway();
      final provider = ScheduleProvider(
        _FakeScheduleService(createHandler: (_) => createCompleter.future),
        notificationGateway,
      );

      final future = provider.createSchedule(_payload());

      expect(provider.schedules, hasLength(1));
      expect(provider.schedules.single.isPendingSync, isTrue);
      expect(provider.schedules.single.displayPlaceName, 'The Cofftea');
      expect(provider.hasPendingSync, isTrue);

      createCompleter.complete(_schedule(id: 'schedule-1'));
      final created = await future;

      expect(created.id, 'schedule-1');
      expect(provider.schedules, hasLength(1));
      expect(provider.schedules.single.id, 'schedule-1');
      expect(provider.schedules.single.isPendingSync, isFalse);
      expect(provider.hasPendingSync, isFalse);
      expect(notificationGateway.scheduledIds, isNotEmpty);
    },
  );

  test(
    'createSchedule supports quick schedules without a saved place',
    () async {
      final provider = ScheduleProvider(
        _FakeScheduleService(
          createHandler: (data) async => Schedule(
            id: 'quick-schedule-1',
            date: DateTime.parse(data['date'] as String),
            time: data['time'] as String,
            status: data['status'] as String,
            hasReminder: data['hasReminder'] as bool,
            title: data['title'] as String,
            note: data['note'] as String,
            mapsUrl: data['mapsUrl'] as String,
          ),
        ),
        _FakeNotificationGateway(),
      );

      final created = await provider.createSchedule({
        'title': 'AN cafe',
        'note': 'View dep, ca phe on',
        'mapsUrl': 'https://maps.app.goo.gl/abc123',
        'date': '2099-01-10',
        'time': '10:00-11:00',
        'status': scheduleStatusUpcoming,
        'hasReminder': false,
      });

      expect(created.placeId, isNull);
      expect(provider.schedules.single.displayPlaceName, 'AN cafe');
      expect(provider.schedules.single.displayAddress, 'View dep, ca phe on');
      expect(
        provider.schedules.single.mapsUrl,
        'https://maps.app.goo.gl/abc123',
      );
    },
  );

  test(
    'updateSchedule rolls back visible state and notifications when sync fails',
    () async {
      final notificationGateway = _FakeNotificationGateway();
      final provider = ScheduleProvider(
        _FakeScheduleService(
          schedules: [_schedule()],
          updateHandler: (id, data) => Future<Schedule>.delayed(
            const Duration(milliseconds: 1),
            () => throw const ApiException('Update failed'),
          ),
        ),
        notificationGateway,
      );

      await provider.fetchSchedules();

      final future = provider.updateSchedule('schedule-1', {
        'hasReminder': false,
        'time': '11:00-12:00',
      });

      expect(provider.schedules.single.hasReminder, isFalse);
      expect(provider.schedules.single.time, '11:00-12:00');
      expect(provider.schedules.single.isPendingSync, isTrue);
      expect(provider.hasPendingSync, isTrue);
      expect(notificationGateway.cancelledIds, isNotEmpty);

      await expectLater(future, throwsA(isA<ApiException>()));

      expect(provider.schedules.single.hasReminder, isTrue);
      expect(provider.schedules.single.time, '10:00-11:30');
      expect(provider.schedules.single.isPendingSync, isFalse);
      expect(provider.hasPendingSync, isFalse);
      expect(notificationGateway.scheduledIds, isNotEmpty);
    },
  );

  test(
    'deleteSchedule restores schedule and reminder state when backend delete fails',
    () async {
      final notificationGateway = _FakeNotificationGateway();
      final provider = ScheduleProvider(
        _FakeScheduleService(
          schedules: [_schedule()],
          deleteHandler: (_) => Future<void>.delayed(
            const Duration(milliseconds: 1),
            () => throw const ApiException('Delete failed'),
          ),
        ),
        notificationGateway,
      );

      await provider.fetchSchedules();
      final existing = provider.schedules.single;

      final future = provider.deleteSchedule(existing.id, schedule: existing);

      expect(provider.schedules, isEmpty);
      expect(provider.hasPendingSync, isTrue);
      expect(notificationGateway.cancelledIds, isNotEmpty);

      await expectLater(future, throwsA(isA<ApiException>()));

      expect(provider.schedules, hasLength(1));
      expect(provider.schedules.single.id, existing.id);
      expect(provider.schedules.single.isPendingSync, isFalse);
      expect(provider.hasPendingSync, isFalse);
      expect(notificationGateway.scheduledIds, isNotEmpty);
    },
  );

  test(
    'updateScheduleStatus reopens a completed schedule and restores reminders',
    () async {
      final notificationGateway = _FakeNotificationGateway();
      final scheduleService = _FakeScheduleService(
        schedules: [_schedule(status: scheduleStatusDone)],
        updateHandler: (id, data) async {
          return _schedule(id: id, status: data['status'] as String);
        },
      );
      final provider = ScheduleProvider(scheduleService, notificationGateway);

      await provider.fetchSchedules();
      final existing = provider.schedules.single;

      await provider.updateScheduleStatus(
        existing.id,
        scheduleStatusUpcoming,
        currentSchedule: existing,
      );

      expect(scheduleService.lastUpdatedId, existing.id);
      expect(scheduleService.lastUpdatePayload, {
        'status': scheduleStatusUpcoming,
      });
      expect(provider.schedules.single.status, scheduleStatusUpcoming);
      expect(provider.schedules.single.isPendingSync, isFalse);
      expect(notificationGateway.scheduledIds, isNotEmpty);
    },
  );
}

class _FakeScheduleService extends ScheduleService {
  _FakeScheduleService({
    List<Schedule>? schedules,
    this.createHandler,
    this.updateHandler,
    this.deleteHandler,
  }) : _schedules = schedules ?? const [],
       super(ApiClient(baseUrl: 'https://example.com'));

  final List<Schedule> _schedules;
  final Future<Schedule> Function(Map<String, dynamic> data)? createHandler;
  final Future<Schedule> Function(String id, Map<String, dynamic> data)?
  updateHandler;
  final Future<void> Function(String id)? deleteHandler;
  String? lastUpdatedId;
  Map<String, dynamic>? lastUpdatePayload;

  @override
  Future<List<Schedule>> getSchedules() async => _schedules;

  @override
  Future<List<Schedule>> getSchedulesByDate(DateTime date) async {
    return _schedules.where((schedule) {
      return schedule.date.year == date.year &&
          schedule.date.month == date.month &&
          schedule.date.day == date.day;
    }).toList();
  }

  @override
  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    if (createHandler != null) {
      return createHandler!(data);
    }
    return _schedule(id: 'created-schedule');
  }

  @override
  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    lastUpdatedId = id;
    lastUpdatePayload = Map<String, dynamic>.from(data);
    if (updateHandler != null) {
      return updateHandler!(id, data);
    }
    return _schedule(id: id);
  }

  @override
  Future<void> deleteSchedule(String id) async {
    if (deleteHandler != null) {
      return deleteHandler!(id);
    }
  }
}

class _FakeNotificationGateway implements NotificationGateway {
  final List<int> scheduledIds = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<int> scheduleNotification(
    DateTime dateTime,
    String title,
    String body, {
    int? id,
  }) async {
    final resolvedId = id ?? dateTime.millisecondsSinceEpoch;
    scheduledIds.add(resolvedId);
    return resolvedId;
  }
}

Schedule _schedule({
  String id = 'schedule-1',
  String status = scheduleStatusUpcoming,
  bool hasReminder = true,
  DateTime? date,
}) {
  return Schedule(
    id: id,
    placeId: 'place-1',
    date: date ?? DateTime(2099, 1, 10),
    time: '10:00-11:30',
    status: status,
    hasReminder: hasReminder,
    placeName: 'The Cofftea',
    category: 'Cafe',
    address: '123 Pho Hue, Ha Noi',
    openingHours: '08:00-22:00',
    mapsUrl: 'https://www.google.com/maps/place/The+Cofftea',
    latitude: 21.02,
    longitude: 105.85,
  );
}

Map<String, dynamic> _payload() {
  return {
    'placeId': 'place-1',
    'date': '2099-01-10',
    'time': '10:00-11:30',
    'status': scheduleStatusUpcoming,
    'hasReminder': true,
    'placeName': 'The Cofftea',
    'category': 'Cafe',
    'address': '123 Pho Hue, Ha Noi',
    'openingHours': '08:00-22:00',
    'mapsUrl': 'https://www.google.com/maps/place/The+Cofftea',
    'latitude': 21.02,
    'longitude': 105.85,
  };
}
