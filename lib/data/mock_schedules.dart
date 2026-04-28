import '../models/schedule.dart';

final mockSchedules = <Schedule>[
  Schedule(
    id: 'schedule-1',
    placeId: 'them-cafe',
    placeName: 'Them Cafe',
    date: DateTime.now(),
    time: '09:30',
    category: 'Cafe',
    address: '2HF2+43C, Tan Xa, Ha Noi',
    status: 'UPCOMING',
    hasReminder: true,
  ),
  Schedule(
    id: 'schedule-2',
    placeId: 'cgv-cinema',
    placeName: 'CGV Cinema',
    date: DateTime.now().add(const Duration(days: 2)),
    time: '19:00',
    category: 'Movie',
    address: 'Vincom Center',
    status: 'UPCOMING',
    hasReminder: true,
  ),
  Schedule(
    id: 'schedule-3',
    placeId: 'highland-coffee',
    placeName: 'Highland Coffee',
    date: DateTime.now().subtract(const Duration(days: 1)),
    time: '15:00',
    category: 'Cafe',
    address: 'Ha Noi, Viet Nam',
    status: 'DONE',
    hasReminder: false,
  ),
];
