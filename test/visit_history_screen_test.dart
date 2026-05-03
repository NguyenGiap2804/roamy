import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/place.dart';
import 'package:roamy/models/schedule.dart';
import 'package:roamy/providers/place_provider.dart';
import 'package:roamy/providers/schedule_provider.dart';
import 'package:roamy/screens/visit_history/visit_history_screen.dart';
import 'package:roamy/services/notification_service.dart';
import 'package:roamy/services/place_service.dart';
import 'package:roamy/services/schedule_service.dart';

void main() {
  testWidgets('visit history shows completed visits and can plan a repeat', (
    tester,
  ) async {
    final completedVisit = _schedule(
      id: 'done-visit',
      status: scheduleStatusDone,
      date: DateTime(2026, 4, 20),
      placeName: 'Visited Cafe',
    );
    final upcomingVisit = _schedule(
      id: 'upcoming-visit',
      status: scheduleStatusUpcoming,
      date: DateTime(2026, 5, 20),
      placeName: 'Future Cafe',
    );
    final scheduleService = _FakeScheduleService(
      schedules: [completedVisit, upcomingVisit],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaceProvider>.value(
            value: _FakePlaceProvider(_place()),
          ),
          ChangeNotifierProvider<ScheduleProvider>.value(
            value: ScheduleProvider(
              scheduleService,
              _FakeNotificationGateway(),
            ),
          ),
        ],
        child: const MaterialApp(home: VisitHistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Visit history'), findsOneWidget);
    expect(find.text('Visited Cafe'), findsOneWidget);
    expect(find.text('Future Cafe'), findsNothing);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);

    await tester.tap(find.byTooltip('Visit again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scheduleService.createdPayloads, hasLength(1));
    expect(scheduleService.createdPayloads.single['placeId'], 'place-1');
    expect(
      scheduleService.createdPayloads.single['status'],
      scheduleStatusUpcoming,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
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

  @override
  Future<List<Schedule>> getSchedules() async => schedules;

  @override
  Future<Schedule> createSchedule(Map<String, dynamic> data) async {
    createdPayloads.add(Map<String, dynamic>.from(data));
    return _schedule(
      id: 'new-repeat-visit',
      status: data['status'] as String? ?? scheduleStatusUpcoming,
      date: DateTime.parse(data['date'] as String),
      time: data['time'] as String? ?? '10:00-11:30',
      hasReminder: data['hasReminder'] as bool? ?? false,
      placeName: data['placeName'] as String? ?? 'Visited Cafe',
    );
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
    name: 'Visited Cafe',
    categoryId: 'category-1',
    address: '123 Pho Hue, Ha Noi',
    priceRange: '100.000d - 200.000d',
    openingHours: '08:00-22:00',
    phone: '0123456789',
    mapsUrl: 'https://www.google.com/maps/place/Visited+Cafe',
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
  String status = scheduleStatusDone,
  DateTime? date,
  String time = '10:00-11:30',
  bool hasReminder = true,
  String placeName = 'Visited Cafe',
}) {
  return Schedule(
    id: id,
    placeId: 'place-1',
    date: date ?? DateTime(2026, 4, 20),
    time: time,
    status: status,
    hasReminder: hasReminder,
    placeName: placeName,
    category: 'Cafe',
    address: '123 Pho Hue, Ha Noi',
    openingHours: '08:00-22:00',
    mapsUrl: 'https://www.google.com/maps/place/Visited+Cafe',
    latitude: 21.02,
    longitude: 105.85,
  );
}
