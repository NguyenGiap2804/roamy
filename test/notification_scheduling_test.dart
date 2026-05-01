import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/models/schedule.dart';
import 'package:roamy/providers/schedule_provider.dart';
import 'package:roamy/services/notification_service.dart';

void main() {
  group('notification scheduling guards', () {
    test('skips exact reminders that are already in the past', () {
      final now = DateTime(2026, 5, 1, 10, 0);
      final schedule = _buildSchedule(
        date: DateTime(2026, 5, 1),
        time: '09:00',
      );

      expect(
        shouldScheduleReminderAt(visitDateTimeForSchedule(schedule), now: now),
        isFalse,
      );
      expect(
        shouldScheduleNotificationAt(
          visitDateTimeForSchedule(schedule),
          now: now,
        ),
        isFalse,
      );
    });

    test(
      'skips 30-minute reminders that are already in the past even if visit is upcoming',
      () {
        final now = DateTime(2026, 5, 1, 8, 45);
        final schedule = _buildSchedule(
          date: DateTime(2026, 5, 1),
          time: '09:00',
        );

        expect(
          shouldScheduleReminderAt(
            advanceReminderDateTimeForSchedule(schedule),
            now: now,
          ),
          isFalse,
        );
        expect(
          shouldScheduleReminderAt(
            visitDateTimeForSchedule(schedule),
            now: now,
          ),
          isTrue,
        );
      },
    );

    test(
      'schedules both reminders when both times are still in the future',
      () {
        final now = DateTime(2026, 5, 1, 8, 0);
        final schedule = _buildSchedule(
          date: DateTime(2026, 5, 1),
          time: '09:00-10:30',
        );

        expect(
          shouldScheduleReminderAt(
            advanceReminderDateTimeForSchedule(schedule),
            now: now,
          ),
          isTrue,
        );
        expect(
          shouldScheduleNotificationAt(
            visitDateTimeForSchedule(schedule),
            now: now,
          ),
          isTrue,
        );
      },
    );

    test('does not schedule reminders exactly at the current time', () {
      final now = DateTime(2026, 5, 1, 9, 0);

      expect(shouldScheduleReminderAt(now, now: now), isFalse);
      expect(shouldScheduleNotificationAt(now, now: now), isFalse);
    });
  });
}

Schedule _buildSchedule({required DateTime date, required String time}) {
  return Schedule(
    id: 'schedule-1',
    placeId: 'place-1',
    date: date,
    time: time,
    status: 'UPCOMING',
    hasReminder: true,
    placeName: 'Sample Place',
  );
}
