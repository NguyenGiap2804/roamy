import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/network/api_client.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._categoryService);

  final CategoryService _categoryService;

  final List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastCategoriesFetchAt;
  Future<void>? _categoriesFetchInFlight;

  static const Duration _categoriesCacheTtl = Duration(minutes: 5);

  List<Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasFreshCategoriesCache()) {
      return;
    }

    final inFlight = _categoriesFetchInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchCategoriesFromApi(showLoading: _categories.isEmpty);
    _categoriesFetchInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_categoriesFetchInFlight, future)) {
        _categoriesFetchInFlight = null;
      }
    }
  }

  Future<void> _fetchCategoriesFromApi({required bool showLoading}) async {
    if (showLoading) _setLoading(true);
    try {
      final categories = await _categoryService.getCategories();
      _categories
        ..clear()
        ..addAll(categories);
      _lastCategoriesFetchAt = DateTime.now();
      _errorMessage = null;
    } catch (error) {
      if (_categories.isEmpty) {
        _errorMessage = error.toString();
      }
    } finally {
      if (showLoading) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    }
  }

  Future<Category?> addCategory(String name) async {
    final existingCategory = findByName(name);
    if (existingCategory != null) {
      final message = 'Danh mục "${existingCategory.name}" đã tồn tại';
      _errorMessage = message;
      notifyListeners();
      throw ApiException(message, statusCode: 409);
    }

    _setLoading(true);
    try {
      final category = await _categoryService.createCategory({
        'name': name,
        'icon': 'category',
      });
      _categories.add(category);
      _lastCategoriesFetchAt = DateTime.now();
      _errorMessage = null;
      return category;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Category? findByName(String name) {
    final normalizedName = _normalizeCategoryName(name);
    for (final category in _categories) {
      if (_normalizeCategoryName(category.name) == normalizedName) {
        return category;
      }
    }
    return null;
  }

  Category? findById(String id) {
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool _hasFreshCategoriesCache() {
    final lastFetchAt = _lastCategoriesFetchAt;
    if (_categories.isEmpty || lastFetchAt == null) {
      return false;
    }

    return DateTime.now().difference(lastFetchAt) < _categoriesCacheTtl;
  }

  String _normalizeCategoryName(String value) {
    return value.trim().toLowerCase();
  }
}
