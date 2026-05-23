import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/place.dart';
import '../../providers/category_provider.dart';
import '../../providers/place_provider.dart';
import '../../services/google_maps_extraction_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/rating_stars.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({
    super.key,
    this.place,
    this.prefilledDraft,
    this.mapsExtractionService,
  });

  final Place? place;
  final Map<String, dynamic>? prefilledDraft;
  final GoogleMapsExtractionService? mapsExtractionService;

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class UploadException implements Exception {
  const UploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapsUrlController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _noteController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _formScrollController = ScrollController();
  final _detailsSectionKey = GlobalKey();

  final ImagePicker _picker = ImagePicker();
  late final GoogleMapsExtractionService _mapsExtractionService;
  File? _selectedImage;
  String? _selectedCategoryId;
  double _rating = 4.5;
  bool _isSaving = false;
  bool _isAutoFilling = false;
  double? _latitude;
  double? _longitude;
  GoogleMapsExtractionReview? _extractionReview;
  bool _showExtractionReview = false;
  bool get _isDuplicateResolutionMode => widget.prefilledDraft != null;

  bool get _isEditing => widget.place != null;
  bool get _hasPreviewData {
    return _nameController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _imageUrlController.text.trim().isNotEmpty ||
        _priceRangeController.text.trim().isNotEmpty ||
        _openingHoursController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _websiteController.text.trim().isNotEmpty ||
        _selectedImage != null ||
        _latitude != null ||
        _longitude != null;
  }

  @override
  void initState() {
    super.initState();
    _mapsExtractionService =
        widget.mapsExtractionService ?? GoogleMapsExtractionService();
    _fillFromPlace(widget.place);
    _applyPrefilledDraft(widget.prefilledDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  @override
  void dispose() {
    _mapsUrlController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _priceRangeController.dispose();
    _openingHoursController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _noteController.dispose();
    _imageUrlController.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  void _fillFromPlace(Place? place) {
    if (place == null) return;
    _mapsUrlController.text = place.mapsUrl ?? '';
    _nameController.text = place.name;
    _addressController.text = place.address;
    _priceRangeController.text = place.priceRange;
    _openingHoursController.text = place.openingHours;
    _phoneController.text = place.phone ?? '';
    _websiteController.text = place.website ?? '';
    _noteController.text = place.note ?? '';
    _imageUrlController.text = place.imageUrl ?? '';
    _selectedCategoryId = place.categoryId;
    _rating = place.rating;
    _latitude = place.latitude;
    _longitude = place.longitude;
  }

  void _applyPrefilledDraft(Map<String, dynamic>? draft) {
    if (draft == null) return;

    _applyDraftText(_mapsUrlController, draft['mapsUrl']);
    _applyDraftText(_nameController, draft['name']);
    _applyDraftText(_addressController, draft['address']);
    _applyDraftText(_priceRangeController, draft['priceRange']);
    _applyDraftText(_openingHoursController, draft['openingHours']);
    _applyDraftText(_phoneController, draft['phone']);
    _applyDraftText(_websiteController, draft['website']);
    _applyDraftText(_noteController, draft['note']);
    _applyDraftText(_imageUrlController, draft['imageUrl']);

    final categoryId = _draftString(draft['categoryId']);
    if (categoryId != null) {
      _selectedCategoryId = categoryId;
    }

    final rating = _draftDouble(draft['rating']);
    if (rating != null) {
      _rating = _clampRating(rating);
    }

    final latitude = _draftDouble(draft['latitude']);
    if (latitude != null) {
      _latitude = latitude;
    }

    final longitude = _draftDouble(draft['longitude']);
    if (longitude != null) {
      _longitude = longitude;
    }
  }

  void _applyDraftText(TextEditingController controller, Object? value) {
    final text = _draftString(value);
    if (text == null) return;
    controller.text = text;
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    const maxUploadBytes = 5 * 1024 * 1024;
    final imageSize = await imageFile.length();
    if (imageSize > maxUploadBytes) {
      throw const UploadException('Hình ảnh phải nhỏ hơn hoặc bằng 5MB');
    }

    final uri = Uri.parse('${ApiEndpoints.baseUrl}/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: _contentTypeForImage(imageFile.path),
      ),
    );

    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseData = await http.Response.fromStream(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonResponse =
          jsonDecode(responseData.body) as Map<String, dynamic>;
      final data = jsonResponse['data'] as Map<String, dynamic>;
      return data['url'] as String?;
    }

    throw UploadException(_uploadErrorMessage(responseData.body));
  }

  MediaType _contentTypeForImage(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return MediaType('image', 'png');
    if (lowerPath.endsWith('.webp')) return MediaType('image', 'webp');
    if (lowerPath.endsWith('.gif')) return MediaType('image', 'gif');
    if (lowerPath.endsWith('.heic')) return MediaType('image', 'heic');
    if (lowerPath.endsWith('.heif')) return MediaType('image', 'heif');
    return MediaType('image', 'jpeg');
  }

  String _uploadErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    return 'Tải ảnh lên thất bại';
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm danh mục'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final categoryName = controller.text.trim();
              if (categoryName.isEmpty) return;

              final provider = context.read<CategoryProvider>();
              final navigator = Navigator.of(dialogContext);

              try {
                final newCategory = await provider.addCategory(categoryName);
                if (mounted) {
                  setState(() => _selectedCategoryId = newCategory?.id);
                }
                navigator.pop();
              } catch (error) {
                if (!context.mounted) return;
                SnackBarHelper.showError(context, error.toString());
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<bool> _autoFillFromMapsUrl({
    bool showFeedback = true,
    bool onlyMissing = false,
  }) async {
    var url = _mapsUrlController.text.trim();
    if (url.isEmpty || _isAutoFilling) return false;
    if (RegExp(r'(^|//)ps\.app\.goo\.gl').hasMatch(url)) {
      url = url.replaceFirst('ps.app.goo.gl', 'maps.app.goo.gl');
      _mapsUrlController.text = url;
    }
    if (!url.startsWith('http')) url = 'https://$url';

    setState(() => _isAutoFilling = true);

    try {
      final placeData = await _mapsExtractionService.extract(url);

      if (!mounted) return false;

      if (placeData.hasAnyData) {
        setState(() {
          _applyExtractedPlaceData(placeData, onlyMissing: onlyMissing);
          final review = placeData.merge(_currentFormPlaceData()).review;
          _extractionReview = review;
          _showExtractionReview = review.needsManualReview;
        });
        if (showFeedback) {
          SnackBarHelper.showSuccess(
            context,
            'Đã tự động điền thông tin từ Google Maps',
          );
        }
        return true;
      } else {
        setState(() {
          _extractionReview = null;
          _showExtractionReview = false;
        });
        if (showFeedback) {
          SnackBarHelper.showError(
            context,
            'Không tìm thấy thông tin trong link này',
          );
        }
      }
    } catch (_) {
      if (!mounted) return false;
      if (showFeedback) {
        SnackBarHelper.showError(context, 'Lỗi trích xuất link Google Maps');
      }
    } finally {
      if (mounted) setState(() => _isAutoFilling = false);
    }
    return false;
  }

  void _applyExtractedPlaceData(
    GoogleMapsPlaceData data, {
    bool onlyMissing = false,
  }) {
    _updateField(_nameController, data.name, onlyMissing: onlyMissing);
    _updateField(_addressController, data.address, onlyMissing: onlyMissing);
    _updateField(
      _priceRangeController,
      data.priceRange,
      onlyMissing: onlyMissing,
    );
    _updateField(
      _openingHoursController,
      data.openingHours,
      onlyMissing: onlyMissing,
    );
    _updateField(_phoneController, data.phone, onlyMissing: onlyMissing);
    _updateField(_websiteController, data.website, onlyMissing: onlyMissing);
    _updateField(_imageUrlController, data.imageUrl, onlyMissing: onlyMissing);
    _rating = data.rating != null ? _clampRating(data.rating!) : _rating;
    _latitude = data.latitude ?? _latitude;
    _longitude = data.longitude ?? _longitude;
  }

  GoogleMapsPlaceData _currentFormPlaceData() {
    return GoogleMapsPlaceData(
      name: _nullableText(_nameController),
      address: _nullableText(_addressController),
      priceRange: _nullableText(_priceRangeController),
      openingHours: _nullableText(_openingHoursController),
      phone: _nullableText(_phoneController),
      website: _nullableText(_websiteController),
      imageUrl: _nullableText(_imageUrlController),
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  void _resetExtractionReview() {
    if (_extractionReview == null && !_showExtractionReview) {
      return;
    }

    setState(() {
      _extractionReview = null;
      _showExtractionReview = false;
    });
  }

  void _handlePreviewFieldChanged(String _) {
    setState(() {});
  }

  void _scrollToDetailsForm() {
    final detailsContext = _detailsSectionKey.currentContext;
    if (detailsContext != null) {
      Scrollable.ensureVisible(
        detailsContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      return;
    }

    if (!_formScrollController.hasClients) return;
    _formScrollController.animateTo(
      _formScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  String _previewCategoryName(CategoryProvider categoryProvider) {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      return _draftString(widget.prefilledDraft?['categoryName']) ?? 'Danh mục';
    }
    return categoryProvider.findById(categoryId)?.name ??
        _draftString(widget.prefilledDraft?['categoryName']) ??
        'Danh mục';
  }

  void _updateField(
    TextEditingController controller,
    String? value, {
    bool onlyMissing = false,
  }) {
    if (value == null || value.trim().isEmpty) return;
    if (onlyMissing && controller.text.trim().isNotEmpty) return;
    controller.text = value.trim();
  }

  Future<void> _handleDuplicatePlaceConflict(
    PlaceProvider placeProvider,
    ApiException error, {
    required Map<String, dynamic> draftPayload,
  }) async {
    final details = _DuplicatePlaceConflictDetails.fromApiException(error);
    Place? duplicatePlace;

    if (details.duplicatePlaceId != null) {
      try {
        duplicatePlace = await placeProvider.getPlaceById(
          details.duplicatePlaceId!,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    final action = await showDialog<_DuplicateConflictAction>(
      context: context,
      builder: (dialogContext) => _DuplicatePlaceConflictDialog(
        message: error.message,
        details: details,
        duplicatePlace: duplicatePlace,
        isEditing: _isEditing,
      ),
    );

    if (!mounted ||
        action != _DuplicateConflictAction.editExisting ||
        duplicatePlace == null) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            AddPlaceScreen(place: duplicatePlace, prefilledDraft: draftPayload),
      ),
    );
  }

  Future<void> _save() async {
    await _autoFillMissingDetailsBeforeSave();
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      SnackBarHelper.showError(context, 'Vui lòng chọn danh mục');
      return;
    }

    final placeProvider = context.read<PlaceProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final navigator = Navigator.of(context);
    final categoryName = categoryProvider.findById(categoryId)?.name;

    setState(() => _isSaving = true);

    var uploadedImageUrl = _nullableText(_imageUrlController);
    if (_selectedImage != null) {
      try {
        uploadedImageUrl = await _uploadImage(_selectedImage!);
      } catch (error) {
        if (!mounted) return;
        SnackBarHelper.showError(context, error.toString());
        setState(() => _isSaving = false);
        return;
      }
    }

    try {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      final priceRange = _priceRangeController.text.trim();
      final openingHours = _openingHoursController.text.trim();
      final phone = _nullableText(_phoneController);
      final website = _nullableText(_websiteController);
      final mapsUrl = _nullableText(_mapsUrlController);
      final note = _nullableText(_noteController);
      final rating = _clampRating(_rating);

      if (_isEditing) {
        final p = widget.place!;
        final hasChanges =
            p.name != name ||
            p.categoryId != categoryId ||
            p.address != address ||
            p.priceRange != priceRange ||
            p.openingHours != openingHours ||
            p.phone != phone ||
            p.website != website ||
            p.mapsUrl != mapsUrl ||
            p.note != note ||
            p.imageUrl != uploadedImageUrl ||
            p.rating != rating ||
            p.latitude != _latitude ||
            p.longitude != _longitude;

        if (!hasChanges) {
          if (mounted) {
            SnackBarHelper.showSuccess(
              context,
              'Không có thông tin được cập nhật',
            );
          }
          navigator.pop();
          return;
        }
      }

      final payload = {
        'name': name,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'address': address,
        'priceRange': priceRange,
        'openingHours': openingHours,
        'phone': phone,
        'website': website,
        'mapsUrl': mapsUrl,
        'note': note,
        'imageUrl': uploadedImageUrl,
        'rating': rating,
        'hasReminder': _isEditing ? widget.place!.hasReminder : false,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      if (_isEditing) {
        await placeProvider.updatePlace(widget.place!.id, payload);
      } else {
        await placeProvider.addPlace(payload);
      }

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        _isEditing
            ? 'Cập nhật thông tin thành công'
            : 'Đã lưu địa điểm thành công',
      );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        await _handleDuplicatePlaceConflict(
          placeProvider,
          error,
          draftPayload: {
            'name': _nameController.text.trim(),
            'categoryId': _selectedCategoryId,
            'categoryName': categoryName,
            'address': _addressController.text.trim(),
            'priceRange': _priceRangeController.text.trim(),
            'openingHours': _openingHoursController.text.trim(),
            'phone': _nullableText(_phoneController),
            'website': _nullableText(_websiteController),
            'mapsUrl': _nullableText(_mapsUrlController),
            'note': _nullableText(_noteController),
            'imageUrl': uploadedImageUrl,
            'rating': _rating,
            'latitude': _latitude,
            'longitude': _longitude,
          },
        );
        return;
      }
      SnackBarHelper.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _autoFillMissingDetailsBeforeSave() async {
    final hasMapsUrl = _mapsUrlController.text.trim().isNotEmpty;
    if (!hasMapsUrl) return;

    final missingDetails =
        _nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _priceRangeController.text.trim().isEmpty ||
        _openingHoursController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _websiteController.text.trim().isEmpty ||
        _imageUrlController.text.trim().isEmpty ||
        _latitude == null ||
        _longitude == null;
    if (!missingDetails) return;

    await _autoFillFromMapsUrl(showFeedback: false, onlyMissing: true);
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _draftString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _draftDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  double _clampRating(double value) {
    return value.clamp(1.0, 5.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Cập nhật địa điểm' : 'Thêm địa điểm'),
      ),
      body: SafeArea(
        child: Consumer<CategoryProvider>(
          builder: (context, categoryProvider, _) {
            if (_selectedCategoryId == null &&
                categoryProvider.categories.isNotEmpty) {
              _selectedCategoryId = categoryProvider.categories.first.id;
            }

            return Form(
              key: _formKey,
              child: ListView(
                controller: _formScrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  Text(
                    _isEditing
                        ? 'Cập nhật địa điểm đã lưu'
                        : 'Lưu địa điểm mới',
                    style: AppTextStyles.headline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEditing
                        ? 'Chỉnh sửa chi tiết và đồng bộ với hệ thống.'
                        : 'Thêm chi tiết và đồng bộ với hệ thống.',
                    style: AppTextStyles.subtitle,
                  ),
                  if (_isDuplicateResolutionMode) ...[
                    const SizedBox(height: 16),
                    const _DuplicateResolutionBanner(),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Input(
                          controller: _mapsUrlController,
                          label: 'Liên kết Google Maps',
                          icon: Icons.link_rounded,
                          requiredField: false,
                          onChanged: (value) {
                            _resetExtractionReview();
                            _handlePreviewFieldChanged(value);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 8),
                        child: IconButton(
                          icon: _isAutoFilling
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.blue,
                                ),
                          onPressed: _isAutoFilling
                              ? null
                              : _autoFillFromMapsUrl,
                          tooltip: 'Tự động điền thông tin',
                        ),
                      ),
                    ],
                  ),
                  if (_showExtractionReview && _extractionReview != null)
                    _ExtractionReviewCard(
                      review: _extractionReview!,
                      onDismiss: () =>
                          setState(() => _showExtractionReview = false),
                    ),
                  if (_isAutoFilling || _hasPreviewData) ...[
                    _PlacePreviewCard(
                      key: const Key('addPlacePreviewCard'),
                      isLoading: _isAutoFilling,
                      name: _nameController.text.trim(),
                      category: _previewCategoryName(categoryProvider),
                      address: _addressController.text.trim(),
                      priceRange: _priceRangeController.text.trim(),
                      openingHours: _openingHoursController.text.trim(),
                      phone: _phoneController.text.trim(),
                      website: _websiteController.text.trim(),
                      imageUrl: _imageUrlController.text.trim(),
                      selectedImage: _selectedImage,
                      rating: _rating,
                      isSaving: _isSaving,
                      onEdit: _scrollToDetailsForm,
                      onSave: _save,
                    ),
                    const SizedBox(height: 16),
                  ],
                  KeyedSubtree(
                    key: _detailsSectionKey,
                    child: KeyedSubtree(
                      key: const Key('addPlaceDetailsSection'),
                      child: _Input(
                        key: const Key('addPlaceNameField'),
                        controller: _nameController,
                        label: 'Tên địa điểm',
                        icon: Icons.place_rounded,
                        onChanged: _handlePreviewFieldChanged,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Danh mục',
                            prefixIcon: Icon(Icons.sell_rounded),
                          ),
                          items: categoryProvider.categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Vui lòng chọn danh mục' : null,
                          onChanged: (value) =>
                              setState(() => _selectedCategoryId = value),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.blue,
                          size: 32,
                        ),
                        onPressed: () => _showAddCategoryDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Input(
                    key: const Key('addPlaceAddressField'),
                    controller: _addressController,
                    label: 'Địa chỉ',
                    icon: Icons.location_on_rounded,
                    onChanged: _handlePreviewFieldChanged,
                  ),
                  _Input(
                    controller: _priceRangeController,
                    label: 'Khoảng giá',
                    icon: Icons.payments_rounded,
                    requiredField: false,
                    onChanged: _handlePreviewFieldChanged,
                  ),
                  _Input(
                    controller: _openingHoursController,
                    label: 'Giờ mở cửa',
                    icon: Icons.schedule_rounded,
                    requiredField: false,
                    onChanged: _handlePreviewFieldChanged,
                  ),
                  _Input(
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    requiredField: false,
                    onChanged: _handlePreviewFieldChanged,
                  ),
                  _Input(
                    controller: _websiteController,
                    label: 'Website',
                    icon: Icons.language_rounded,
                    keyboardType: TextInputType.url,
                    requiredField: false,
                    onChanged: _handlePreviewFieldChanged,
                  ),
                  const Text(
                    'Hình ảnh địa điểm',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.8),
                            child: IconButton(
                              icon: Icon(
                                Icons.edit_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_imageUrlController.text.trim().isNotEmpty)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageUrlController.text.trim(),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 120,
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.8),
                            child: IconButton(
                              icon: Icon(
                                Icons.edit_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Chọn hình ảnh',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _Input(
                    controller: _noteController,
                    label: 'Ghi chú cá nhân',
                    icon: Icons.edit_note_rounded,
                    maxLines: 4,
                    requiredField: false,
                  ),
                  const SizedBox(height: 18),
                  if (categoryProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        categoryProvider.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  PrimaryButton(
                    key: const Key('addPlaceFormSaveButton'),
                    label: _isSaving
                        ? 'Đang lưu...'
                        : (_isEditing ? 'Cập nhật địa điểm' : 'Lưu địa điểm'),
                    icon: Icons.check_rounded,
                    onPressed: _isSaving ? () {} : _save,
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlacePreviewCard extends StatelessWidget {
  const _PlacePreviewCard({
    super.key,
    required this.isLoading,
    required this.name,
    required this.category,
    required this.address,
    required this.priceRange,
    required this.openingHours,
    required this.phone,
    required this.website,
    required this.imageUrl,
    required this.selectedImage,
    required this.rating,
    required this.isSaving,
    required this.onEdit,
    required this.onSave,
  });

  final bool isLoading;
  final String name;
  final String category;
  final String address;
  final String priceRange;
  final String openingHours;
  final String phone;
  final String website;
  final String imageUrl;
  final File? selectedImage;
  final double rating;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: isLoading ? const _PlacePreviewSkeleton() : _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final displayName = name.isEmpty ? 'Địa điểm mới' : name;
    final hasAddress = address.isNotEmpty;
    final hasPriceRange = priceRange.isNotEmpty;
    final hasOpeningHours = openingHours.isNotEmpty;
    final hasPhone = phone.isNotEmpty;
    final hasWebsite = website.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewImage(
          selectedImage: selectedImage,
          imageUrl: imageUrl,
          name: displayName,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PreviewChip(label: category),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              RatingStars(
                rating: rating,
                compact: true,
                textColor: Theme.of(context).colorScheme.onSurface,
              ),
              if (hasAddress) ...[
                const SizedBox(height: AppSpacing.md),
                _PreviewMetaRow(icon: Icons.location_on_rounded, text: address),
              ],
              if (hasOpeningHours)
                _PreviewMetaRow(
                  icon: Icons.schedule_rounded,
                  text: openingHours,
                ),
              if (hasPhone)
                _PreviewMetaRow(icon: Icons.phone_rounded, text: phone),
              if (hasWebsite)
                _PreviewMetaRow(icon: Icons.language_rounded, text: website),
              if (hasPriceRange)
                _PreviewMetaRow(icon: Icons.payments_rounded, text: priceRange),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('addPlacePreviewEditButton'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Chỉnh sửa'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('addPlacePreviewSaveButton'),
                      onPressed: isSaving ? null : onSave,
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bookmark_add_rounded),
                      label: Text(isSaving ? 'Đang lưu...' : 'Lưu địa điểm'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({
    required this.selectedImage,
    required this.imageUrl,
    required this.name,
  });

  final File? selectedImage;
  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final selected = selectedImage;
    if (selected != null) {
      return Image.file(
        selected,
        height: 172,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: 172,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      height: 172,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarySoft, Color(0xFFE9F7F4)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.place_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title.copyWith(color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMetaRow extends StatelessWidget {
  const _PreviewMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sell_rounded, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacePreviewSkeleton extends StatelessWidget {
  const _PlacePreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(height: 150, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: AppSpacing.lg),
          const _SkeletonBox(widthFactor: 0.7, height: 20),
          const SizedBox(height: AppSpacing.sm),
          const _SkeletonBox(widthFactor: 0.45, height: 14),
          const SizedBox(height: AppSpacing.md),
          const _SkeletonBox(widthFactor: 0.9, height: 14),
          const SizedBox(height: AppSpacing.sm),
          const _SkeletonBox(widthFactor: 0.62, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.widthFactor = 1,
    required this.height,
    this.borderRadius,
  });

  final double widthFactor;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          borderRadius: borderRadius ?? BorderRadius.circular(999),
        ),
      ),
    );
  }
}

enum _DuplicateConflictAction { stay, editExisting }

class _DuplicatePlaceConflictDetails {
  const _DuplicatePlaceConflictDetails({
    this.duplicatePlaceId,
    this.duplicateReason,
  });

  final String? duplicatePlaceId;
  final String? duplicateReason;

  factory _DuplicatePlaceConflictDetails.fromApiException(ApiException error) {
    final details = error.details;
    if (details is! Map<String, dynamic>) {
      return const _DuplicatePlaceConflictDetails();
    }

    return _DuplicatePlaceConflictDetails(
      duplicatePlaceId: _readNonEmptyString(details['duplicatePlaceId']),
      duplicateReason: _readNonEmptyString(details['duplicateReason']),
    );
  }

  String? get reasonLabel {
    switch (duplicateReason) {
      case 'maps-url':
        return 'Trung lien ket Google Maps';
      case 'coordinates':
        return 'Trung ten va vi tri ban do';
      case 'name-address':
        return 'Trung ten va dia chi';
      default:
        return null;
    }
  }
}

class _DuplicateResolutionBanner extends StatelessWidget {
  const _DuplicateResolutionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.merge_type_rounded, color: AppColors.orange),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dang xu ly duplicate place',
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Form nay dang dung du lieu vua nhap de cap nhat dia diem da co, giup ban hop nhat thong tin ma khong phai nhap lai.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicatePlaceConflictDialog extends StatelessWidget {
  const _DuplicatePlaceConflictDialog({
    required this.message,
    required this.details,
    required this.duplicatePlace,
    required this.isEditing,
  });

  final String message;
  final _DuplicatePlaceConflictDetails? details;
  final Place? duplicatePlace;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = duplicatePlace;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.copy_all_rounded,
              color: AppColors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isEditing
                  ? 'Co dia diem khac dang trung'
                  : 'Dia diem nay da ton tai',
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppTextStyles.body),
            if (details?.reasonLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  details!.reasonLabel!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
            if (place != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Dia diem dang co trong he thong',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      place.address,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.sell_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(place.category, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_DuplicateConflictAction.stay),
          child: const Text('Quay lai form'),
        ),
        if (place != null)
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pop(_DuplicateConflictAction.editExisting),
            icon: const Icon(Icons.edit_location_alt_rounded),
            label: Text(
              isEditing ? 'Mo dia diem kia' : 'Cap nhat dia diem da co',
            ),
          ),
      ],
    );
  }
}

class _ExtractionReviewCard extends StatelessWidget {
  const _ExtractionReviewCard({required this.review, required this.onDismiss});

  final GoogleMapsExtractionReview review;
  final VoidCallback onDismiss;

  Color _accentColor() {
    switch (review.confidence) {
      case GoogleMapsExtractionConfidence.low:
        return AppColors.red;
      case GoogleMapsExtractionConfidence.medium:
        return AppColors.orange;
      case GoogleMapsExtractionConfidence.high:
        return AppColors.green;
    }
  }

  IconData _icon() {
    switch (review.confidence) {
      case GoogleMapsExtractionConfidence.low:
        return Icons.warning_amber_rounded;
      case GoogleMapsExtractionConfidence.medium:
        return Icons.rule_rounded;
      case GoogleMapsExtractionConfidence.high:
        return Icons.verified_rounded;
    }
  }

  String _title() {
    switch (review.confidence) {
      case GoogleMapsExtractionConfidence.low:
        return 'Can bo sung thu cong';
      case GoogleMapsExtractionConfidence.medium:
        return 'Nen kiem tra lai truoc khi luu';
      case GoogleMapsExtractionConfidence.high:
        return 'Du lieu Google Maps kha day du';
    }
  }

  String _subtitle() {
    switch (review.confidence) {
      case GoogleMapsExtractionConfidence.low:
        return 'Link nay chi tra ve mot phan thong tin.';
      case GoogleMapsExtractionConfidence.medium:
        return 'Da autofill duoc du lieu co ban, nhung van nen doi chieu.';
      case GoogleMapsExtractionConfidence.high:
        return 'Du lieu da du de luu.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(), color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title(), style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_subtitle()} ${(review.score * 100).round()}% tin cay.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (review.capturedFields.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Da lay duoc: ${review.capturedFields.join(', ')}',
              style: AppTextStyles.body.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
          if (review.issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final issue in review.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(issue, style: AppTextStyles.body)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.requiredField = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool requiredField;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: (value) {
          if (!requiredField) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label không được để trống';
          }
          return null;
        },
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

String? _readNonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
