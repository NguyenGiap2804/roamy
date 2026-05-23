import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/core/network/api_client.dart';
import 'package:roamy/models/category.dart';
import 'package:roamy/providers/category_provider.dart';
import 'package:roamy/services/category_service.dart';

void main() {
  test(
    'fetchCategories returns cached categories without waiting for a second API call',
    () async {
      var calls = 0;
      final secondCall = Completer<List<Category>>();
      final service = _FakeCategoryService(
        getCategoriesHandler: () {
          calls += 1;
          if (calls == 1) {
            return Future.value([_category()]);
          }
          return secondCall.future;
        },
      );
      final provider = CategoryProvider(service);

      await provider.fetchCategories();
      await expectLater(
        provider.fetchCategories().timeout(const Duration(milliseconds: 100)),
        completes,
      );

      expect(calls, 1);
      expect(provider.categories, hasLength(1));
      expect(provider.categories.single.name, 'Cafe');
    },
  );
}

class _FakeCategoryService extends CategoryService {
  _FakeCategoryService({this.getCategoriesHandler})
    : super(ApiClient(baseUrl: 'https://example.com'));

  final Future<List<Category>> Function()? getCategoriesHandler;

  @override
  Future<List<Category>> getCategories() {
    if (getCategoriesHandler != null) {
      return getCategoriesHandler!();
    }
    return Future.value([_category()]);
  }
}

Category _category() {
  return const Category(
    id: 'cat-1',
    name: 'Cafe',
    icon: 'category',
    placeCount: 0,
  );
}
