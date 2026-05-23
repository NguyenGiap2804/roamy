import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/place.dart';
import 'package:roamy/providers/place_provider.dart';
import 'package:roamy/services/place_service.dart';

void main() {
  test(
    'addPlace inserts an optimistic place before the backend responds',
    () async {
      final createCompleter = Completer<Place>();
      final service = _FakePlaceService(
        createPlaceHandler: (_) => createCompleter.future,
      );
      final provider = PlaceProvider(service);

      final future = provider.addPlace(_payload(name: 'Optimistic Cafe'));

      expect(provider.places, hasLength(1));
      expect(provider.places.single.name, 'Optimistic Cafe');
      expect(provider.places.single.isPendingSync, isTrue);
      expect(provider.hasPendingSync, isTrue);

      createCompleter.complete(_place(id: 'place-1', name: 'Optimistic Cafe'));
      await future;

      expect(provider.places, hasLength(1));
      expect(provider.places.single.id, 'place-1');
      expect(provider.places.single.isPendingSync, isFalse);
      expect(provider.hasPendingSync, isFalse);
    },
  );

  test(
    'fetchPlaces returns cached places without waiting for a second API call',
    () async {
      var calls = 0;
      final secondCall = Completer<List<Place>>();
      final service = _FakePlaceService(
        getPlacesHandler: ({String? categoryId}) {
          calls += 1;
          if (calls == 1) {
            return Future.value([_place()]);
          }
          return secondCall.future;
        },
      );
      final provider = PlaceProvider(service);

      await provider.fetchPlaces();
      await expectLater(
        provider.fetchPlaces().timeout(const Duration(milliseconds: 100)),
        completes,
      );

      expect(calls, 1);
      expect(provider.places, hasLength(1));
      expect(provider.places.single.name, 'The Cofftea');
    },
  );

  test(
    'updatePlace rolls back the optimistic change when backend sync fails',
    () async {
      final updateCompleter = Completer<Place>();
      final service = _FakePlaceService(
        places: [_place()],
        updatePlaceHandler: (ignoredId, ignoredData) => updateCompleter.future,
      );
      final provider = PlaceProvider(service);
      await provider.fetchPlaces();

      final future = provider.updatePlace('place-1', {
        'name': 'Renamed Cafe',
        'categoryName': 'Cafe',
      });

      expect(provider.places.single.name, 'Renamed Cafe');
      expect(provider.places.single.isPendingSync, isTrue);
      expect(provider.hasPendingSync, isTrue);

      updateCompleter.completeError(const ApiException('Update failed'));
      await expectLater(future, throwsA(isA<ApiException>()));

      expect(provider.places.single.name, 'The Cofftea');
      expect(provider.places.single.isPendingSync, isFalse);
      expect(provider.hasPendingSync, isFalse);
    },
  );

  test(
    'deletePlace removes locally first and restores the place when sync fails',
    () async {
      final deleteCompleter = Completer<void>();
      final service = _FakePlaceService(
        places: [_place()],
        deletePlaceHandler: (_) => deleteCompleter.future,
      );
      final provider = PlaceProvider(service);
      await provider.fetchPlaces();

      final future = provider.deletePlace('place-1');

      expect(provider.places, isEmpty);
      expect(provider.hasPendingSync, isTrue);

      deleteCompleter.completeError(const ApiException('Delete failed'));
      await expectLater(future, throwsA(isA<ApiException>()));

      expect(provider.places, hasLength(1));
      expect(provider.places.single.id, 'place-1');
      expect(provider.hasPendingSync, isFalse);
    },
  );
}

class _FakePlaceService extends PlaceService {
  _FakePlaceService({
    List<Place>? places,
    this.getPlacesHandler,
    this.createPlaceHandler,
    this.updatePlaceHandler,
    this.deletePlaceHandler,
  }) : _places = places ?? const [],
       super(ApiClient(baseUrl: 'https://example.com'));

  final List<Place> _places;
  final Future<List<Place>> Function({String? categoryId})? getPlacesHandler;
  final Future<Place> Function(Map<String, dynamic> data)? createPlaceHandler;
  final Future<Place> Function(String id, Map<String, dynamic> data)?
  updatePlaceHandler;
  final Future<void> Function(String id)? deletePlaceHandler;

  @override
  Future<List<Place>> getPlaces({String? categoryId}) async {
    if (getPlacesHandler != null) {
      return getPlacesHandler!(categoryId: categoryId);
    }
    return _places;
  }

  @override
  Future<Place> createPlace(Map<String, dynamic> data) async {
    if (createPlaceHandler != null) {
      return createPlaceHandler!(data);
    }
    return _place(
      id: 'created-place',
      name: data['name'] as String? ?? 'Created Place',
    );
  }

  @override
  Future<Place> updatePlace(String id, Map<String, dynamic> data) async {
    if (updatePlaceHandler != null) {
      return updatePlaceHandler!(id, data);
    }
    return _place(id: id, name: data['name'] as String? ?? 'Updated Place');
  }

  @override
  Future<void> deletePlace(String id) async {
    if (deletePlaceHandler != null) {
      return deletePlaceHandler!(id);
    }
  }
}

Place _place({String id = 'place-1', String name = 'The Cofftea'}) {
  return Place(
    id: id,
    name: name,
    categoryId: 'cat-1',
    address: '123 Pho Hue, Ha Noi',
    priceRange: '',
    openingHours: '',
    rating: 4.6,
    hasReminder: false,
    categoryName: 'Cafe',
  );
}

Map<String, dynamic> _payload({required String name}) {
  return {
    'name': name,
    'categoryId': 'cat-1',
    'categoryName': 'Cafe',
    'address': '123 Pho Hue, Ha Noi',
    'priceRange': '',
    'openingHours': '',
    'phone': null,
    'mapsUrl': null,
    'note': null,
    'imageUrl': null,
    'rating': 4.6,
    'hasReminder': false,
    'latitude': 21.03,
    'longitude': 105.85,
  };
}
