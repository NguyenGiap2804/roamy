import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/network/api_endpoints.dart';
import '../../models/place.dart';
import '../../providers/category_provider.dart';
import '../../providers/place_provider.dart';
import '../../services/google_maps_extraction_service.dart';
import '../../widgets/primary_button.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key, this.place});

  final Place? place;

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
  final _noteController = TextEditingController();
  final _imageUrlController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final GoogleMapsExtractionService _mapsExtractionService =
      GoogleMapsExtractionService();
  File? _selectedImage;
  String? _selectedCategoryId;
  double _rating = 4.5;
  bool _isSaving = false;
  bool _isAutoFilling = false;
  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.place != null;

  @override
  void initState() {
    super.initState();
    _fillFromPlace(widget.place);
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
    _noteController.dispose();
    _imageUrlController.dispose();
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
    _noteController.text = place.note ?? '';
    _imageUrlController.text = place.imageUrl ?? '';
    _selectedCategoryId = place.categoryId;
    _rating = place.rating;
    _latitude = place.latitude;
    _longitude = place.longitude;
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
      throw const UploadException('Image must be 5MB or smaller');
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

    return 'Failed to upload image';
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
              final messenger = ScaffoldMessenger.of(context);

              try {
                final newCategory = await provider.addCategory(categoryName);
                if (mounted) {
                  setState(() => _selectedCategoryId = newCategory?.id);
                }
                navigator.pop();
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoFillFromMapsUrl() async {
    var url = _mapsUrlController.text.trim();
    if (url.isEmpty) return;
    if (RegExp(r'(^|//)ps\.app\.goo\.gl').hasMatch(url)) {
      url = url.replaceFirst('ps.app.goo.gl', 'maps.app.goo.gl');
      _mapsUrlController.text = url;
    }
    if (!url.startsWith('http')) url = 'https://$url';

    setState(() => _isAutoFilling = true);

    try {
      final placeData = await _mapsExtractionService.extract(url);

      if (!mounted) return;

      if (placeData.hasAnyData) {
        setState(() => _applyExtractedPlaceData(placeData));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tự động điền thông tin từ Google Maps'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy thông tin trong link này'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi trích xuất link Google Maps')),
      );
    } finally {
      if (mounted) setState(() => _isAutoFilling = false);
    }
  }

  void _applyExtractedPlaceData(GoogleMapsPlaceData data) {
    _updateField(_nameController, data.name);
    _updateField(_addressController, data.address);
    _updateField(_openingHoursController, data.openingHours);
    _updateField(_phoneController, data.phone);
    _rating = data.rating ?? _rating;
    _latitude = data.latitude ?? _latitude;
    _longitude = data.longitude ?? _longitude;
  }

  void _updateField(TextEditingController controller, String? value) {
    if (value == null || value.trim().isEmpty) return;
    controller.text = value.trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final placeProvider = context.read<PlaceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    var uploadedImageUrl = _nullableText(_imageUrlController);
    if (_selectedImage != null) {
      try {
        uploadedImageUrl = await _uploadImage(_selectedImage!);
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() => _isSaving = false);
        return;
      }
    }

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'categoryId': categoryId,
        'address': _addressController.text.trim(),
        'priceRange': _nullableText(_priceRangeController),
        'openingHours': _nullableText(_openingHoursController),
        'phone': _nullableText(_phoneController),
        'mapsUrl': _nullableText(_mapsUrlController),
        'note': _nullableText(_noteController),
        'imageUrl': uploadedImageUrl,
        'rating': _rating,
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Cập nhật thông tin thành công'
                : 'Place saved successfully',
          ),
        ),
      );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Update Place' : 'Add Place')),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  Text(
                    _isEditing ? 'Update saved place' : 'Save somewhere new',
                    style: AppTextStyles.headline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEditing
                        ? 'Edit details and sync changes to Roamy Backend.'
                        : 'Add details and sync them to Roamy Backend.',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Input(
                          controller: _mapsUrlController,
                          label: 'Google Maps link',
                          icon: Icons.link_rounded,
                          requiredField: false,
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
                          tooltip: 'Auto-fill info',
                        ),
                      ),
                    ],
                  ),
                  _Input(
                    controller: _nameController,
                    label: 'Place name',
                    icon: Icons.place_rounded,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
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
                              value == null ? 'Category is required' : null,
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
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.location_on_rounded,
                  ),
                  _Input(
                    controller: _priceRangeController,
                    label: 'Price range',
                    icon: Icons.payments_rounded,
                    requiredField: false,
                  ),
                  _Input(
                    controller: _openingHoursController,
                    label: 'Opening hours',
                    icon: Icons.schedule_rounded,
                    requiredField: false,
                  ),
                  _Input(
                    controller: _phoneController,
                    label: 'Phone number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    requiredField: false,
                  ),
                  const Text(
                    'Place Image',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
                            backgroundColor: Theme.of(context).colorScheme.surface.withValues(
                              alpha: 0.8,
                            ),
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
                  else if (_isEditing &&
                      _imageUrlController.text.trim().isNotEmpty)
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
                                  color: Theme.of(context).colorScheme.surface,
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
                            backgroundColor: Theme.of(context).colorScheme.surface.withValues(
                              alpha: 0.8,
                            ),
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
                          border: Border.all(color: Theme.of(context).dividerColor),
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
                              'Select Image',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _Input(
                    controller: _noteController,
                    label: 'Personal note',
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
                    label: _isSaving
                        ? 'Saving...'
                        : (_isEditing ? 'Update place' : 'Save place'),
                    icon: Icons.check_rounded,
                    onPressed: _isSaving ? () {} : _save,
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 24,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.requiredField = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (!requiredField) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}
