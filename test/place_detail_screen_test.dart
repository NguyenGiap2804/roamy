import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/place.dart';
import 'package:roamy/models/schedule.dart';
import 'package:roamy/providers/place_provider.dart';
import 'package:roamy/providers/schedule_provider.dart';
import 'package:roamy/screens/place_detail/place_detail_screen.dart';
import 'package:roamy/services/notification_service.dart';
import 'package:roamy/services/place_service.dart';
import 'package:roamy/services/schedule_service.dart';

void main() {
  testWidgets(
    'schedule planner keeps upcoming schedules selected across months when saving unchanged',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => binding.setSurfaceSize(null));

      final now = DateTime.now();
      final place = _place();
      final scheduleService = _FakeScheduleService(
        schedules: [
          _schedule(
            id: 'schedule-current-month',
            date: DateTime(now.year, now.month, now.day + 2),
          ),
          _schedule(
            id: 'schedule-next-month',
            date: DateTime(now.year, now.month + 1, 5),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlaceProvider>.value(
              value: _FakePlaceProvider(place),
            ),
            ChangeNotifierProvider<ScheduleProvider>.value(
              value: ScheduleProvider(
                scheduleService,
                _FakeNotificationGateway(),
              ),
            ),
          ],
          child: MaterialApp(home: PlaceDetailScreen(place: place)),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final scheduleButton = find.byIcon(Icons.event_rounded);
      await tester.ensureVisible(scheduleButton);
      await tester.pumpAndSettle();
      await tester.tap(scheduleButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(scheduleService.createdPayloads, isEmpty);
      expect(scheduleService.updatedPayloads, isEmpty);
      expect(scheduleService.deletedIds, isEmpty);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('place detail opens share card sheet', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => binding.setSurfaceSize(null));

    final place = _place();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaceProvider>.value(
            value: _FakePlaceProvider(place),
          ),
          ChangeNotifierProvider<ScheduleProvider>.value(
            value: ScheduleProvider(
              _FakeScheduleService(schedules: const []),
              _FakeNotificationGateway(),
            ),
          ),
        ],
        child: MaterialApp(home: PlaceDetailScreen(place: place)),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Share card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share card'));
    await tester.pumpAndSettle();

    expect(find.text('Share Roamy Card'), findsOneWidget);
    expect(find.text('Share now'), findsOneWidget);
    expect(find.text('Saved with Roamy'), findsOneWidget);
  });
}

class _FakePlaceProvider extends PlaceProvider {
  _FakePlaceProvider(this.place)
    : super(PlaceService(ApiClient(baseUrl: 'https://example.com')));

  final Place place;

  @override
  Future<Place> getPlaceById(String id) async => place;
}

class _FakeScheduleService extends ScheduleService {
  _FakeScheduleService({required this.schedules})
    : super(ApiClient(baseUrl: 'https://example.com'));

  final List<Schedule> schedules;
  final List<Map<String, dynamic>> createdPayloads = [];
  final List<Map<String, dynamic>> updatedPayloads = [];
  final List<String> deletedIds = [];

  @override
  Future<List<Schedule>> getSchedules() async => schedules;

  @override
  Future<List<Schedule>> getSchedulesByDate(DateTime date) async {
    return schedules.where((schedule) {
      return schedule.date.year == date.year &&
          schedule.date.month == date.month &&
          schedule.date.day == date.day;
    }).toList();
  }

  @override
  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    createdPayloads.add(Map<String, dynamic>.from(data));
    return _schedule(
      id: 'created-schedule',
      date: DateTime.parse(data['date'] as String),
      time: data['time'] as String? ?? '10:00-11:30',
      hasReminder: data['hasReminder'] as bool? ?? false,
    );
  }

  @override
  Future<Schedule> updateSchedule(String id, Map<String, dynamic> data) async {
    updatedPayloads.add({'id': id, ...Map<String, dynamic>.from(data)});
    return _schedule(
      id: id,
      date: data['date'] is String
          ? DateTime.parse(data['date'] as String)
          : schedules.firstWhere((schedule) => schedule.id == id).date,
      time: data['time'] as String? ?? '10:00-11:30',
      hasReminder: data['hasReminder'] as bool? ?? true,
      status: data['status'] as String? ?? scheduleStatusUpcoming,
    );
  }

  @override
  Future<void> deleteSchedule(String id) async {
    deletedIds.add(id);
  }
}

class _FakeNotificationGateway implements NotificationGateway {
  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<int> scheduleNotification(
    DateTime dateTime,
    String title,
    String body, {
    int? id,
  }) async {
    return id ?? dateTime.millisecondsSinceEpoch;
  }
}

Place _place() {
  return const Place(
    id: 'place-1',
    name: 'The Cofftea',
    categoryId: 'category-1',
    address: '123 Pho Hue, Ha Noi',
    priceRange: '100.000d - 200.000d',
    openingHours: '08:00-22:00',
    phone: '0123456789',
    mapsUrl: 'https://www.google.com/maps/place/The+Cofftea',
    note: 'Best in town',
    imageUrl: '',
    rating: 4.5,
    hasReminder: true,
    categoryName: 'Cafe',
    latitude: 21.02,
    longitude: 105.85,
  );
}

Schedule _schedule({
  String id = 'schedule-1',
  DateTime? date,
  String time = '10:00-11:30',
  bool hasReminder = true,
  String status = scheduleStatusUpcoming,
}) {
  return Schedule(
    id: id,
    placeId: 'place-1',
    date: date ?? DateTime(2099, 1, 10),
    time: time,
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
