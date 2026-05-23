import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roamy/models/nearby_place.dart';
import 'package:roamy/services/google_places_service.dart';

void main() {
  test('builds Google Maps URL from place name before coordinates', () {
    final place = NearbyPlace.fromOverpassJson({
      'type': 'node',
      'id': 43,
      'lat': 21.080670,
      'lon': 105.958843,
      'tags': {
        'name': 'AN Kinh Bac - Den Do',
        'amenity': 'cafe',
        'addr:street': 'Pho Co Phap',
      },
    });

    final uri = Uri.parse(place.mapsUrl);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['query'], contains('AN Kinh Bac - Den Do'));
    expect(uri.queryParameters['query'], isNot(contains('21.080670')));
  });

  test('falls back to coordinates for Google Maps URL without a name', () {
    final place = NearbyPlace.fromOverpassJson({
      'type': 'node',
      'id': 44,
      'lat': 21.080670,
      'lon': 105.958843,
      'tags': {'amenity': 'cafe'},
    });

    expect(
      Uri.parse(place.mapsUrl).queryParameters['query'],
      '21.08067,105.958843',
    );
  });

  test('builds add-place draft with the nearby image URL', () {
    const place = NearbyPlace(
      placeId: 'node/45',
      name: 'AN Kinh Bac - Den Do',
      address: '',
      rating: 7,
      latitude: 21.080670,
      longitude: 105.958843,
      photoUrl: 'https://example.com/map-photo.jpg',
      category: 'Cafe',
      categoryBase: 'Cafe',
      openingHours: '08:00-22:00',
      phone: '+84 123',
      mapsUrl: 'https://www.google.com/maps/search/?api=1&query=AN',
    );

    final draft = place.toAddPlaceDraft(
      resolvedAddress: '18 Pho Co Phap, Bac Ninh',
    );

    expect(draft['address'], '18 Pho Co Phap, Bac Ninh');
    expect(draft['imageUrl'], 'https://example.com/map-photo.jpg');
    expect(draft['mapsUrl'], place.mapsUrl);
    expect(draft['latitude'], 21.080670);
    expect(draft['longitude'], 105.958843);
  });

  test('builds add-place draft with enriched Google Maps details first', () {
    const place = NearbyPlace(
      placeId: 'node/46',
      name: 'nhe cafe - Den Do',
      address: '42 Pho Co Phap',
      rating: 2,
      latitude: 21.080670,
      longitude: 105.958843,
      category: 'Cafe',
      categoryBase: 'Cafe',
      mapsUrl: 'https://www.google.com/maps/search/?api=1&query=nhe',
    );

    final draft = place.toAddPlaceDraft(
      name: 'nhẹ cafe - Đền Đô',
      address: '42, Phố Cổ Pháp, Phường Đình Bảng, Thành phố Từ Sơn, Bắc Ninh',
      rating: 4.6,
      priceRange: '1-100.000 đ/người',
      openingHours: 'Đang mở cửa · Đóng cửa vào 22:30',
      phone: '+84 869 622 074',
      imageUrl: 'https://lh5.googleusercontent.com/p/photo=w408-h306-k-no',
    );

    expect(draft['name'], 'nhẹ cafe - Đền Đô');
    expect(
      draft['address'],
      '42, Phố Cổ Pháp, Phường Đình Bảng, Thành phố Từ Sơn, Bắc Ninh',
    );
    expect(draft['rating'], 4.6);
    expect(draft['priceRange'], '1-100.000 đ/người');
    expect(draft['openingHours'], 'Đang mở cửa · Đóng cửa vào 22:30');
    expect(draft['phone'], '+84 869 622 074');
    expect(
      draft['imageUrl'],
      'https://lh5.googleusercontent.com/p/photo=w408-h306-k-no',
    );
  });

  test('builds nearby place coordinates from Overpass center', () {
    final place = NearbyPlace.fromOverpassJson({
      'type': 'way',
      'id': 42,
      'center': {'lat': 21.0227921, 'lon': 105.550495},
      'tags': {'name': 'Thềm Cafe', 'amenity': 'cafe'},
    });

    expect(place.latitude, 21.0227921);
    expect(place.longitude, 105.550495);
  });

  test('rejects Overpass places without usable coordinates', () {
    expect(
      () => NearbyPlace.fromOverpassJson({
        'type': 'relation',
        'id': 99,
        'tags': {'name': 'Missing Coordinates', 'amenity': 'cafe'},
      }),
      throwsFormatException,
    );
  });

  test('rejects Nominatim places without usable coordinates', () {
    expect(
      () => NearbyPlace.fromNominatimJson({
        'place_id': 100,
        'display_name': 'Missing Coordinates, Hà Nội',
      }),
      throwsFormatException,
    );
  });

  test('nearby search skips Overpass elements without coordinates', () async {
    final service = ExploreApiService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'elements': [
                {
                  'type': 'relation',
                  'id': 1,
                  'tags': {'name': 'Broken Cafe', 'amenity': 'cafe'},
                },
                {
                  'type': 'way',
                  'id': 2,
                  'center': {'lat': 21.0227921, 'lon': 105.550495},
                  'tags': {
                    'name': 'Thềm Cafe',
                    'amenity': 'cafe',
                    'image': 'https://example.com/them-cafe.jpg',
                  },
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final places = await service.searchNearby(
      latitude: 21.02,
      longitude: 105.55,
    );

    expect(places, hasLength(1));
    expect(places.single.name, 'Thềm Cafe');
    expect(places.single.latitude, 21.0227921);
    expect(places.single.longitude, 105.550495);
  });

  test('text search skips Nominatim results without coordinates', () async {
    final service = ExploreApiService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'place_id': 1, 'display_name': 'Broken Cafe, Hà Nội'},
              {
                'place_id': 2,
                'display_name': 'Thềm Cafe, Thạch Hoà, Hà Nội',
                'lat': '21.0227921',
                'lon': '105.550495',
                'category': 'amenity',
                'type': 'cafe',
                'importance': 0.6,
              },
            ]),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final places = await service.searchByText(
      query: 'cafe',
      latitude: 21.02,
      longitude: 105.55,
    );

    expect(places, hasLength(1));
    expect(places.single.name, 'Thềm Cafe');
    expect(places.single.latitude, 21.0227921);
    expect(places.single.longitude, 105.550495);
  });
}
