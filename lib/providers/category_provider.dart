import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._categoryService);

  final CategoryService _categoryService;

  final List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCategories() async {
    _setLoading(true);
    try {
      final categories = await _categoryService.getCategories();
      _categories
        ..clear()
        ..addAll(categories);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Category?> addCategory(String name) async {
    _setLoading(true);
    try {
      final category = await _categoryService.createCategory({
        'name': name,
        'icon': 'category',
      });
      _categories.add(category);
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
    for (final category in _categories) {
      if (category.name == name) return category;
    }
    return null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
