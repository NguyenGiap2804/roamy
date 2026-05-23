import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/category.dart';
import 'package:roamy/models/place.dart';
import 'package:roamy/providers/category_provider.dart';
import 'package:roamy/providers/place_provider.dart';
import 'package:roamy/screens/add_place/add_place_screen.dart';
import 'package:roamy/services/category_service.dart';
import 'package:roamy/services/place_service.dart';

void main() {
  testWidgets(
    'duplicate conflict dialog can open existing place in resolution mode',
    (tester) async {
      final duplicatePlace = Place(
        id: 'existing-place',
        name: 'The Cofftea',
        categoryId: 'cat-1',
        address: '123 Pho Hue, Ha Noi',
        priceRange: '',
        openingHours: '',
        rating: 4.6,
        hasReminder: false,
        categoryName: 'Cafe',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => CategoryProvider(_FakeCategoryService()),
            ),
            ChangeNotifierProvider(
              create: (_) => PlaceProvider(
                _FakePlaceService(duplicatePlace: duplicatePlace),
              ),
            ),
          ],
          child: const MaterialApp(home: AddPlaceScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(1), 'The Cofftea');
      await tester.enterText(textFields.at(2), '123 Pho Hue, Ha Noi');
      await tester.scrollUntilVisible(
        find.byIcon(Icons.check_rounded),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Dia diem nay da ton tai'), findsOneWidget);
      expect(find.text('Cap nhat dia diem da co'), findsOneWidget);

      await tester.tap(find.text('Cap nhat dia diem da co'));
      await tester.pumpAndSettle();

      expect(find.text('Dang xu ly duplicate place'), findsOneWidget);
      expect(find.text('The Cofftea'), findsWidgets);
    },
  );

  testWidgets('prefilled nearby score is clamped before saving', (
    tester,
  ) async {
    final placeService = _CapturingPlaceService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(_FakeCategoryService()),
          ),
          ChangeNotifierProvider(create: (_) => PlaceProvider(placeService)),
        ],
        child: const MaterialApp(
          home: AddPlaceScreen(
            prefilledDraft: {
              'name': 'Thềm Cafe',
              'address': 'Thạch Hoà, Hà Nội',
              'rating': 8.0,
              'latitude': 21.0227921,
              'longitude': 105.550495,
              'mapsUrl':
                  'https://www.google.com/maps/search/?api=1&query=21.0227921,105.550495',
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.check_rounded),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(placeService.createdData?['rating'], 5.0);
    await tester.pump(const Duration(seconds: 3));
  });
}

class _FakeCategoryService extends CategoryService {
  _FakeCategoryService() : super(ApiClient(baseUrl: 'https://example.com'));

  @override
  Future<List<Category>> getCategories() async {
    return const [Category(id: 'cat-1', name: 'Cafe', icon: 'local_cafe')];
  }
}

class _FakePlaceService extends PlaceService {
  _FakePlaceService({required this.duplicatePlace})
    : super(ApiClient(baseUrl: 'https://example.com'));

  final Place duplicatePlace;

  @override
  Future<Place> createPlace(Map<String, dynamic> data) async {
    throw const ApiException(
      'Dia diem "The Cofftea" da ton tai (trung lien ket Google Maps)',
      statusCode: 409,
      details: {
        'duplicatePlaceId': 'existing-place',
        'duplicateReason': 'maps-url',
      },
    );
  }

  @override
  Future<Place> getPlaceById(String id) async {
    return duplicatePlace;
  }
}

class _CapturingPlaceService extends PlaceService {
  _CapturingPlaceService() : super(ApiClient(baseUrl: 'https://example.com'));

  Map<String, dynamic>? createdData;

  @override
  Future<Place> createPlace(Map<String, dynamic> data) async {
    createdData = Map<String, dynamic>.from(data);
    return Place(
      id: 'new-place',
      name: data['name'] as String,
      categoryId: data['categoryId'] as String,
      address: data['address'] as String,
      priceRange: data['priceRange'] as String,
      openingHours: data['openingHours'] as String,
      phone: data['phone'] as String?,
      mapsUrl: data['mapsUrl'] as String?,
      note: data['note'] as String?,
      imageUrl: data['imageUrl'] as String?,
      rating: (data['rating'] as num).toDouble(),
      hasReminder: data['hasReminder'] as bool,
      categoryName: data['categoryName'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}
