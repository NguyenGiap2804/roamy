import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/schedule.dart';
import 'package:roamy/providers/schedule_provider.dart';
import 'package:roamy/screens/calendar/calendar_screen.dart';
import 'package:roamy/services/notification_service.dart';
import 'package:roamy/services/schedule_service.dart';

void main() {
  testWidgets(
    'calendar quick view shows status actions and marks schedule done',
    (tester) async {
      final today = DateTime.now();
      final notificationGateway = _FakeNotificationGateway();
      final scheduleService = _FakeScheduleService(
        schedules: [
          _schedule(date: DateTime(today.year, today.month, today.day)),
        ],
        updateHandler: (id, data) async {
          return _schedule(
            id: id,
            date: DateTime(today.year, today.month, today.day),
            status: data['status'] as String,
          );
        },
      );
      final provider = ScheduleProvider(scheduleService, notificationGateway);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('The Cofftea'), findsOneWidget);

      await tester.tap(find.text('The Cofftea'));
      await tester.pumpAndSettle();

      expect(find.text('Da di xong'), findsOneWidget);
      expect(find.text('Huy lich'), findsOneWidget);

      await tester.ensureVisible(find.text('Da di xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Da di xong'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(scheduleService.lastUpdatedId, 'schedule-1');
      expect(scheduleService.lastUpdatePayload, {'status': scheduleStatusDone});
      expect(provider.schedules.single.status, scheduleStatusDone);
      expect(notificationGateway.cancelledIds, isNotEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'calendar filters schedules by status and shows filter empty state',
    (tester) async {
      final today = DateTime.now();
      final provider = ScheduleProvider(
        _FakeScheduleService(
          schedules: [
            _schedule(
              id: 'schedule-upcoming',
              placeName: 'Upcoming Place',
              date: DateTime(today.year, today.month, today.day),
            ),
            _schedule(
              id: 'schedule-done',
              placeName: 'Done Place',
              status: scheduleStatusDone,
              date: DateTime(today.year, today.month, today.day),
            ),
          ],
        ),
        _FakeNotificationGateway(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Tat ca (2)'), findsOneWidget);
      expect(find.text('Upcoming Place'), findsOneWidget);

      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Done Place'), findsOneWidget);
      expect(find.text('Upcoming Place'), findsNothing);

      await tester.tap(find.text('Cancelled (0)'));
      await tester.pumpAndSettle();

      expect(find.text('Khong co lich phu hop'), findsOneWidget);
      expect(find.text('Done Place'), findsNothing);
      expect(find.text('Upcoming Place'), findsNothing);
    },
  );

  testWidgets('calendar quick edit updates reminder without leaving calendar', (
    tester,
  ) async {
    final today = DateTime.now();
    final notificationGateway = _FakeNotificationGateway();
    final scheduleService = _FakeScheduleService(
      schedules: [
        _schedule(
          id: 'schedule-quick-edit',
          date: DateTime(today.year, today.month, today.day),
        ),
      ],
      updateHandler: (id, data) async {
        return _patchedSchedule(
          _schedule(id: id, date: DateTime(today.year, today.month, today.day)),
          data,
        );
      },
    );
    final provider = ScheduleProvider(scheduleService, notificationGateway);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('The Cofftea'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Chinh nhanh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chinh nhanh'));
    await tester.pumpAndSettle();

    expect(find.text('Luu thay doi'), findsOneWidget);

    await tester.tap(find.text('Nhac nho'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Luu thay doi'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scheduleService.lastUpdatedId, 'schedule-quick-edit');
    expect(scheduleService.lastUpdatePayload, {
      'time': '10:00-11:30',
      'hasReminder': false,
    });
    expect(provider.schedules.single.hasReminder, isFalse);
    expect(notificationGateway.cancelledIds, isNotEmpty);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

class _FakeScheduleService extends ScheduleService {
  _FakeScheduleService({List<Schedule>? schedules, this.updateHandler})
    : _schedules = schedules ?? const [],
      super(ApiClient(baseUrl: 'https://example.com'));

  final List<Schedule> _schedules;
  final Future<Schedule> Function(String id, Map<String, dynamic> data)?
  updateHandler;
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
  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    lastUpdatedId = id;
    lastUpdatePayload = Map<String, dynamic>.from(data);
    if (updateHandler != null) {
      return updateHandler!(id, data);
    }
    return _schedule(id: id);
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
  DateTime? date,
  String placeName = 'The Cofftea',
  String time = '10:00-11:30',
  bool hasReminder = true,
}) {
  return Schedule(
    id: id,
    placeId: 'place-1',
    date: date ?? DateTime(2099, 1, 10),
    time: time,
    status: status,
    hasReminder: hasReminder,
    placeName: placeName,
    category: 'Cafe',
    address: '123 Pho Hue, Ha Noi',
    openingHours: '08:00-22:00',
    mapsUrl: 'https://www.google.com/maps/place/The+Cofftea',
    latitude: 21.02,
    longitude: 105.85,
  );
}

Schedule _patchedSchedule(Schedule schedule, Map<String, dynamic> data) {
  return schedule.copyWith(
    time: data['time'] as String? ?? schedule.time,
    hasReminder: data['hasReminder'] as bool? ?? schedule.hasReminder,
    status: data['status'] as String? ?? schedule.status,
  );
}
