import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/core/utils/coordinates.dart';
import 'package:roamy/models/place.dart';
import 'package:roamy/models/schedule.dart';

void main() {
  group('hasUsableCoordinates', () {
    test('returns false when both coordinates are zero', () {
      expect(hasUsableCoordinates(0, 0), isFalse);
    });

    test('returns false when coordinates are missing or out of range', () {
      expect(hasUsableCoordinates(null, 105.8), isFalse);
      expect(hasUsableCoordinates(21.0, null), isFalse);
      expect(hasUsableCoordinates(95.0, 105.8), isFalse);
      expect(hasUsableCoordinates(21.0, 190.0), isFalse);
    });

    test('returns true for a real place coordinate pair', () {
      expect(hasUsableCoordinates(21.0285, 105.8542), isTrue);
    });
  });

  group('model coordinate guards', () {
    test('place treats 0,0 as missing coordinates', () {
      final place = Place(
        id: 'place-1',
        name: 'No coordinate place',
        categoryId: 'cat-1',
        address: 'Ha Noi',
        priceRange: '',
        openingHours: '',
        rating: 4.5,
        hasReminder: false,
        latitude: 0,
        longitude: 0,
      );

      expect(place.hasCoordinates, isFalse);
    });

    test('schedule treats 0,0 as missing coordinates', () {
      final schedule = Schedule(
        id: 'schedule-1',
        placeId: 'place-1',
        date: DateTime(2026, 5, 1),
        time: '09:00',
        status: 'UPCOMING',
        hasReminder: false,
        latitude: 0,
        longitude: 0,
      );

      expect(schedule.hasCoordinates, isFalse);
    });
  });
}
