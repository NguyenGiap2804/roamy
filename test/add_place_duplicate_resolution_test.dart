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
import 'package:roamy/services/google_maps_extraction_service.dart';
import 'package:roamy/services/place_service.dart';

void main() {
  testWidgets(
    'duplicate conflict dialog can open existing place in resolution mode',
    (tester) async {
      await _useTallSurface(tester);
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

      await tester.enterText(
        find.byKey(const Key('addPlaceNameField')),
        'The Cofftea',
      );
      await tester.enterText(
        find.byKey(const Key('addPlaceAddressField')),
        '123 Pho Hue, Ha Noi',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('addPlaceFormSaveButton')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('addPlaceFormSaveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Dia diem nay da ton tai'), findsOneWidget);
      expect(find.text('Cap nhat dia diem da co'), findsOneWidget);

      await tester.tap(find.text('Cap nhat dia diem da co'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Dang xu ly duplicate place'), findsOneWidget);
      expect(find.text('The Cofftea'), findsWidgets);
    },
  );

  testWidgets('prefilled nearby score is clamped before saving', (
    tester,
  ) async {
    await _useTallSurface(tester);
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
      find.byKey(const Key('addPlaceFormSaveButton')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('addPlaceFormSaveButton')));
    await tester.pumpAndSettle();

    expect(placeService.createdData?['rating'], 5.0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('prefilled draft shows a place preview before the form', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(_FakeCategoryService()),
          ),
          ChangeNotifierProvider(
            create: (_) => PlaceProvider(_CapturingPlaceService()),
          ),
        ],
        child: const MaterialApp(
          home: AddPlaceScreen(
            prefilledDraft: {
              'name': 'nhe cafe - Kinh Bac Flagship',
              'categoryName': 'Cafe',
              'address': '01 D. Le Quang Dao, Tu Son, Bac Ninh',
              'priceRange': '1-100.000 d/nguoi',
              'openingHours': '08:00-22:30',
              'phone': '+84 869 622 074',
              'imageUrl': 'https://example.com/cafe.jpg',
              'rating': 4.8,
              'latitude': 21.115297,
              'longitude': 105.958210,
              'mapsUrl':
                  'https://www.google.com/maps/search/?api=1&query=nhe+cafe',
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addPlacePreviewCard')), findsOneWidget);
    expect(find.text('nhe cafe - Kinh Bac Flagship'), findsWidgets);
    expect(find.text('01 D. Le Quang Dao, Tu Son, Bac Ninh'), findsWidgets);
    expect(find.text('1-100.000 d/nguoi'), findsWidgets);
    expect(find.text('08:00-22:30'), findsWidgets);
    expect(find.text('+84 869 622 074'), findsWidgets);
    expect(find.byKey(const Key('addPlacePreviewEditButton')), findsOneWidget);
    expect(find.byKey(const Key('addPlacePreviewSaveButton')), findsOneWidget);
  });

  testWidgets('preview edit action scrolls to the editable form', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(_FakeCategoryService()),
          ),
          ChangeNotifierProvider(
            create: (_) => PlaceProvider(_CapturingPlaceService()),
          ),
        ],
        child: const MaterialApp(
          home: AddPlaceScreen(
            prefilledDraft: {
              'name': 'The Cofftea',
              'address': '123 Pho Hue, Ha Noi',
              'priceRange': '100.000d - 200.000d',
              'openingHours': '08:00-22:00',
              'phone': '0123456789',
              'imageUrl': 'https://example.com/the-cofftea.jpg',
              'rating': 4.6,
              'latitude': 21.02,
              'longitude': 105.85,
              'mapsUrl': 'https://www.google.com/maps/place/The+Cofftea',
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('addPlacePreviewEditButton')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('addPlacePreviewEditButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addPlaceDetailsSection')), findsOneWidget);
  });

  testWidgets('preview save action uses the existing save payload', (
    tester,
  ) async {
    await _useTallSurface(tester);
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
              'name': 'The Cofftea',
              'address': '123 Pho Hue, Ha Noi',
              'priceRange': '100.000d - 200.000d',
              'openingHours': '08:00-22:00',
              'phone': '0123456789',
              'imageUrl': 'https://example.com/the-cofftea.jpg',
              'rating': 4.6,
              'latitude': 21.02,
              'longitude': 105.85,
              'mapsUrl': 'https://www.google.com/maps/place/The+Cofftea',
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('addPlacePreviewSaveButton')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('addPlacePreviewSaveButton')));
    await tester.pumpAndSettle();

    expect(placeService.createdData?['name'], 'The Cofftea');
    expect(placeService.createdData?['address'], '123 Pho Hue, Ha Noi');
    expect(
      placeService.createdData?['imageUrl'],
      'https://example.com/the-cofftea.jpg',
    );
    expect(placeService.createdData?['rating'], 4.6);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('save auto-fills missing details from a Google Maps link', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final placeService = _CapturingPlaceService();
    final mapsService = _FakeMapsExtractionService(
      const GoogleMapsPlaceData(
        name: 'AN cafe - Kinh Bac Signature',
        address: '1-2 D. Tran Phu, Tu Son, Bac Ninh',
        priceRange: '1-100.000 d/nguoi',
        openingHours: 'Dang mo cua',
        phone: '+84 869 622 074',
        website: 'https://ancafe.vn',
        imageUrl: 'https://example.com/an-cafe.jpg',
        rating: 4.4,
        latitude: 21.115297,
        longitude: 105.958210,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(_FakeCategoryService()),
          ),
          ChangeNotifierProvider(create: (_) => PlaceProvider(placeService)),
        ],
        child: MaterialApp(
          home: AddPlaceScreen(mapsExtractionService: mapsService),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'https://maps.app.goo.gl/test-place',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('addPlaceFormSaveButton')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('addPlaceFormSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(mapsService.calls, 1);
    expect(placeService.createdData?['name'], 'AN cafe - Kinh Bac Signature');
    expect(
      placeService.createdData?['address'],
      '1-2 D. Tran Phu, Tu Son, Bac Ninh',
    );
    expect(
      placeService.createdData?['imageUrl'],
      'https://example.com/an-cafe.jpg',
    );
    expect(placeService.createdData?['website'], 'https://ancafe.vn');
    expect(placeService.createdData?['rating'], 4.4);
    expect(placeService.createdData?['latitude'], 21.115297);
    expect(placeService.createdData?['longitude'], 105.958210);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('save enriches missing Maps details without replacing edits', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final placeService = _CapturingPlaceService();
    final mapsService = _FakeMapsExtractionService(
      const GoogleMapsPlaceData(
        name: 'Extracted cafe',
        address: 'Extracted address',
        priceRange: '1-100.000 d/nguoi',
        openingHours: 'Dang mo cua',
        phone: '+84 869 622 074',
        website: 'https://ancafe.vn',
        imageUrl: 'https://example.com/an-cafe.jpg',
        rating: 4.4,
        latitude: 21.115297,
        longitude: 105.958210,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(_FakeCategoryService()),
          ),
          ChangeNotifierProvider(create: (_) => PlaceProvider(placeService)),
        ],
        child: MaterialApp(
          home: AddPlaceScreen(
            prefilledDraft: const {
              'mapsUrl': 'https://maps.app.goo.gl/test-place',
              'name': 'Manual cafe name',
              'address': 'Manual edited address',
            },
            mapsExtractionService: mapsService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('addPlaceFormSaveButton')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('addPlaceFormSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(mapsService.calls, 1);
    expect(placeService.createdData?['name'], 'Manual cafe name');
    expect(placeService.createdData?['address'], 'Manual edited address');
    expect(placeService.createdData?['phone'], '+84 869 622 074');
    expect(placeService.createdData?['website'], 'https://ancafe.vn');
    expect(
      placeService.createdData?['imageUrl'],
      'https://example.com/an-cafe.jpg',
    );
    expect(placeService.createdData?['latitude'], 21.115297);
    expect(placeService.createdData?['longitude'], 105.958210);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

class _FakeMapsExtractionService extends GoogleMapsExtractionService {
  _FakeMapsExtractionService(this.data);

  final GoogleMapsPlaceData data;
  int calls = 0;

  @override
  Future<GoogleMapsPlaceData> extract(String rawUrl) async {
    calls += 1;
    return data;
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
