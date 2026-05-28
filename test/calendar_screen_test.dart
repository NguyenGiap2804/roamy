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

  testWidgets('calendar shows quick schedules as a compact map card', (
    tester,
  ) async {
    final today = DateTime.now();
    final provider = ScheduleProvider(
      _FakeScheduleService(
        schedules: [
          _quickSchedule(date: DateTime(today.year, today.month, today.day)),
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

    expect(find.text('Tên địa điểm:'), findsOneWidget);
    expect(find.text('AN cafe'), findsOneWidget);
    expect(find.text('Comment:'), findsOneWidget);
    expect(find.text('Cà phê ổn, view đẹp'), findsOneWidget);
    expect(find.text('8 - 9h'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
  });

  testWidgets('quick schedule sheet submits rows with reminders enabled', (
    tester,
  ) async {
    final today = DateTime.now();
    final scheduleService = _FakeScheduleService(
      createHandler: (data) async => _quickSchedule(
        id: 'quick-created',
        date: DateTime.parse(data['date'] as String),
        title: data['title'] as String,
        note: data['note'] as String,
        mapsUrl: data['mapsUrl'] as String,
        time: data['time'] as String,
        hasReminder: data['hasReminder'] as bool,
      ),
    );
    final provider = ScheduleProvider(
      scheduleService,
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

    await tester.tap(find.text('Thêm nhanh'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quick-title-0')), 'AN cafe');
    await tester.enterText(
      find.byKey(const Key('quick-note-0')),
      'Cà phê ổn, view đẹp',
    );
    await tester.enterText(
      find.byKey(const Key('quick-maps-url-0')),
      'https://maps.app.goo.gl/abc123',
    );
    await tester.tap(find.text('Lưu lịch trình'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scheduleService.lastCreatePayload?['title'], 'AN cafe');
    expect(
      scheduleService.lastCreatePayload?['mapsUrl'],
      'https://maps.app.goo.gl/abc123',
    );
    expect(scheduleService.lastCreatePayload?['hasReminder'], isTrue);
    expect(provider.schedules.single.hasReminder, isTrue);
    expect(provider.schedules.single.displayPlaceName, 'AN cafe');
    expect(today, isNotNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

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

  testWidgets('calendar quick edit updates quick schedule details', (
    tester,
  ) async {
    final today = DateTime.now();
    final scheduleService = _FakeScheduleService(
      schedules: [
        _quickSchedule(date: DateTime(today.year, today.month, today.day)),
      ],
      updateHandler: (id, data) async {
        return _patchedSchedule(
          _quickSchedule(
            id: id,
            date: DateTime(today.year, today.month, today.day),
          ),
          data,
        );
      },
    );
    final provider = ScheduleProvider(
      scheduleService,
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

    await tester.tap(find.text('AN cafe'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Chinh nhanh'));
    await tester.tap(find.text('Chinh nhanh'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quick-edit-title')),
      'Bun cu ky',
    );
    await tester.enterText(
      find.byKey(const Key('quick-edit-note')),
      '2268 gieng don',
    );
    await tester.enterText(
      find.byKey(const Key('quick-edit-maps-url')),
      'https://maps.app.goo.gl/changed',
    );

    await tester.tap(find.text('Nhac nho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luu thay doi'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scheduleService.lastUpdatedId, 'quick-schedule-1');
    expect(scheduleService.lastUpdatePayload, {
      'title': 'Bun cu ky',
      'note': '2268 gieng don',
      'mapsUrl': 'https://maps.app.goo.gl/changed',
      'date': _dateToApi(DateTime(today.year, today.month, today.day)),
      'time': '08:00-09:00',
      'hasReminder': false,
    });
    expect(provider.schedules.single.displayPlaceName, 'Bun cu ky');
    expect(provider.schedules.single.displayAddress, '2268 gieng don');
    expect(
      provider.schedules.single.mapsUrl,
      'https://maps.app.goo.gl/changed',
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('quick schedule cards show relative day status badges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final provider = ScheduleProvider(
      _FakeScheduleService(
        returnAllForDate: true,
        schedules: [
          _quickSchedule(
            id: 'quick-yesterday',
            title: 'Yesterday quick',
            date: today.subtract(const Duration(days: 1)),
          ),
          _quickSchedule(id: 'quick-today', title: 'Today quick', date: today),
          _quickSchedule(
            id: 'quick-tomorrow',
            title: 'Tomorrow quick',
            date: today.add(const Duration(days: 1)),
          ),
          _quickSchedule(
            id: 'quick-later',
            title: 'Later quick',
            date: today.add(const Duration(days: 2)),
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

    expect(find.text('Outday'), findsOneWidget);
    expect(find.text('Inday'), findsOneWidget);
    expect(find.text('Next day'), findsOneWidget);
    expect(find.text('Later quick'), findsOneWidget);
  });
}

class _FakeScheduleService extends ScheduleService {
  _FakeScheduleService({
    List<Schedule>? schedules,
    this.createHandler,
    this.updateHandler,
    this.returnAllForDate = false,
  }) : _schedules = List<Schedule>.of(schedules ?? const []),
       super(ApiClient(baseUrl: 'https://example.com'));

  final List<Schedule> _schedules;
  final Future<Schedule> Function(Map<String, dynamic> data)? createHandler;
  final Future<Schedule> Function(String id, Map<String, dynamic> data)?
  updateHandler;
  final bool returnAllForDate;
  Map<String, dynamic>? lastCreatePayload;
  String? lastUpdatedId;
  Map<String, dynamic>? lastUpdatePayload;

  @override
  Future<List<Schedule>> getSchedules() async => _schedules;

  @override
  Future<List<Schedule>> getSchedulesByDate(DateTime date) async {
    if (returnAllForDate) return _schedules;
    return _schedules.where((schedule) {
      return schedule.date.year == date.year &&
          schedule.date.month == date.month &&
          schedule.date.day == date.day;
    }).toList();
  }

  @override
  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    lastCreatePayload = Map<String, dynamic>.from(data);
    if (createHandler != null) {
      final schedule = await createHandler!(data);
      _schedules.add(schedule);
      return schedule;
    }
    final schedule = _quickSchedule();
    _schedules.add(schedule);
    return schedule;
  }

  @override
  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    lastUpdatedId = id;
    lastUpdatePayload = Map<String, dynamic>.from(data);
    if (updateHandler != null) {
      final schedule = await updateHandler!(id, data);
      final index = _schedules.indexWhere((item) => item.id == id);
      if (index == -1) {
        _schedules.add(schedule);
      } else {
        _schedules[index] = schedule;
      }
      return schedule;
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

Schedule _quickSchedule({
  String id = 'quick-schedule-1',
  DateTime? date,
  String title = 'AN cafe',
  String note = 'Cà phê ổn, view đẹp',
  String mapsUrl = 'https://maps.app.goo.gl/abc123',
  String time = '08:00-09:00',
  bool hasReminder = true,
}) {
  return Schedule(
    id: id,
    date: date ?? DateTime(2099, 1, 10),
    time: time,
    status: scheduleStatusUpcoming,
    hasReminder: hasReminder,
    title: title,
    note: note,
    mapsUrl: mapsUrl,
  );
}

Schedule _patchedSchedule(Schedule schedule, Map<String, dynamic> data) {
  return schedule.copyWith(
    title: data['title'] as String? ?? schedule.title,
    note: data['note'] as String? ?? schedule.note,
    mapsUrl: data['mapsUrl'] as String? ?? schedule.mapsUrl,
    date: data['date'] is String
        ? DateTime.parse(data['date'] as String)
        : schedule.date,
    time: data['time'] as String? ?? schedule.time,
    hasReminder: data['hasReminder'] as bool? ?? schedule.hasReminder,
    status: data['status'] as String? ?? schedule.status,
  );
}

String _dateToApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
