import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/models/place.dart';
import 'package:roamy/services/place_share_service.dart';

void main() {
  test('buildShareText includes key place metadata', () {
    final service = PlaceShareService(gateway: _NoopPlaceShareGateway());
    final place = _place();

    final text = service.buildShareText(place);

    expect(text, contains('Roamy pick: The Cofftea'));
    expect(text, contains('Cafe • 4.5 stars'));
    expect(text, contains('Open: 08:00-22:00'));
    expect(text, contains('Price: 100.000d - 200.000d'));
    expect(text, contains('https://www.google.com/maps/place/The+Cofftea'));
  });

  test('buildFileName normalizes place name for safe sharing', () {
    final service = PlaceShareService(gateway: _NoopPlaceShareGateway());
    final place = _place(name: 'The Cofftea @ Hanoi!');

    expect(service.buildFileName(place), 'roamy-card-the-cofftea-hanoi.png');
  });
}

class _NoopPlaceShareGateway implements PlaceShareGateway {
  @override
  Future<void> share({
    required file,
    required String text,
    required String subject,
  }) async {}
}

Place _place({String name = 'The Cofftea'}) {
  return Place(
    id: 'place-1',
    name: name,
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
