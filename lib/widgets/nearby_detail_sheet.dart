import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../core/utils/google_maps_urls.dart';
import '../models/nearby_place.dart';
import '../providers/explore_provider.dart';
import '../screens/add_place/add_place_screen.dart';
import '../services/google_maps_extraction_service.dart';

/// Bottom sheet that shows details of a [NearbyPlace].
///
/// Actions:
/// - Open in Google Maps (uses geo: URI — named pin at exact coordinates)
/// - Save to Roamy (pre-fills ALL available OSM data directly)
class NearbyDetailSheet extends StatefulWidget {
  const NearbyDetailSheet({super.key, required this.place});

  final NearbyPlace place;

  static Future<void> show(BuildContext context, NearbyPlace place) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NearbyDetailSheet(place: place),
    );
  }

  @override
  State<NearbyDetailSheet> createState() => _NearbyDetailSheetState();
}

class _NearbyDetailSheetState extends State<NearbyDetailSheet> {
  final _mapsExtractionService = GoogleMapsExtractionService();
  String? _resolvedAddress;
  GoogleMapsPlaceData? _googleMapsDetails;
  bool _loadingAddress = false;
  bool _loadingGoogleMapsDetails = false;

  NearbyPlace get place => widget.place;

  @override
  void initState() {
    super.initState();
    // If OSM has no address, fetch via reverse geocode immediately
    if (place.address.isEmpty) {
      _fetchAddress();
    }
    _fetchGoogleMapsDetails();
  }

  Future<void> _fetchAddress() async {
    setState(() => _loadingAddress = true);
    try {
      final address = await context.read<ExploreProvider>().reverseGeocodePlace(
        place.latitude,
        place.longitude,
      );
      if (mounted && address != null && address.isNotEmpty) {
        setState(() => _resolvedAddress = address);
      }
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  String get _displayAddress {
    return _firstNonBlank(
          _googleMapsDetails?.address,
          place.address,
          _resolvedAddress,
        ) ??
        '';
  }

  String get _displayName {
    return _firstNonBlank(_googleMapsDetails?.name, place.name) ?? place.name;
  }

  double get _displayRating {
    return _googleMapsDetails?.rating ?? place.rating;
  }

  String? get _displayPriceRange {
    return _firstNonBlank(_googleMapsDetails?.priceRange);
  }

  String? get _displayOpeningHours {
    return _firstNonBlank(_googleMapsDetails?.openingHours, place.openingHours);
  }

  String? get _displayPhone {
    return _firstNonBlank(_googleMapsDetails?.phone, place.phone);
  }

  String? get _displayImageUrl {
    return _firstNonBlank(_googleMapsDetails?.imageUrl, place.photoUrl);
  }

  Future<void> _fetchGoogleMapsDetails() async {
    if (place.mapsUrl.trim().isEmpty) return;
    setState(() => _loadingGoogleMapsDetails = true);
    try {
      final details = await _mapsExtractionService.extract(place.mapsUrl);
      if (mounted && details.hasAnyData) {
        setState(() => _googleMapsDetails = details);
      }
    } catch (_) {
      // Nearby data is still usable when Google Maps enrichment is unavailable.
    } finally {
      if (mounted) setState(() => _loadingGoogleMapsDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails =
        _displayAddress.isNotEmpty ||
        _displayPriceRange != null ||
        _displayOpeningHours != null ||
        _displayPhone != null ||
        _displayImageUrl != null ||
        (place.website != null && place.website!.isNotEmpty) ||
        (place.cuisine != null && place.cuisine!.isNotEmpty);

    return DraggableScrollableSheet(
      initialChildSize: hasDetails ? 0.72 : 0.42,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Name + category chip in one row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _displayName,
                    style: AppTextStyles.headline.copyWith(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.sell_rounded, label: place.category),
              ],
            ),
            const SizedBox(height: 16),

            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Details ──
            if (_displayImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    _displayImageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),

            if (_loadingGoogleMapsDetails)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang cập nhật chi tiết từ Google Maps...',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_displayAddress.isNotEmpty || _loadingAddress)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _loadingAddress
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              _displayAddress,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

            if (_displayRating > 0)
              _DetailRow(
                icon: Icons.star_rounded,
                text: '${_displayRating.toStringAsFixed(1)}/5',
              ),

            if (_displayPriceRange != null)
              _DetailRow(
                icon: Icons.payments_rounded,
                text: _displayPriceRange!,
              ),

            if (_displayOpeningHours != null)
              _DetailRow(
                icon: Icons.schedule_rounded,
                text: _displayOpeningHours!,
              ),

            if (place.cuisine != null && place.cuisine!.isNotEmpty)
              _DetailRow(
                icon: Icons.restaurant_rounded,
                text: place.cuisine!.split(';').map((c) => c.trim()).join(', '),
              ),

            if (_displayPhone != null)
              _TappableDetailRow(
                icon: Icons.phone_rounded,
                text: _displayPhone!,
                onTap: () => launchUrl(
                  Uri.parse('tel:$_displayPhone'),
                  mode: LaunchMode.externalApplication,
                ),
              ),

            if (place.website != null && place.website!.isNotEmpty)
              _TappableDetailRow(
                icon: Icons.language_rounded,
                text: place.website!
                    .replaceFirst(RegExp(r'^https?://'), '')
                    .replaceFirst(RegExp(r'/$'), ''),
                onTap: () => launchUrl(
                  Uri.parse(place.website!),
                  mode: LaunchMode.externalApplication,
                ),
              ),

            // No-data hint
            if (!hasDetails && !_loadingAddress && !_loadingGoogleMapsDetails)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chưa có thông tin chi tiết. Nhấn "Lưu vào Roamy" để điền thêm.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(context),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Google Maps'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveToRoamy(context),
                    icon: const Icon(Icons.bookmark_add_rounded),
                    label: const Text('Lưu vào Roamy'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        );
      },
    );
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final lat = place.latitude;
    final lng = place.longitude;
    final mapsUri = buildGoogleMapsLaunchUri(
      mapsUrl: place.mapsUrl,
      name: place.name,
      address: _displayAddress,
      latitude: lat,
      longitude: lng,
    );

    try {
      if (mapsUri != null) {
        final launched = await launchUrl(
          mapsUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {}

    final fallbackUri = buildGoogleMapsSearchUri(latitude: lat, longitude: lng);
    try {
      final launched = await launchUrl(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps')));
    }
  }

  void _saveToRoamy(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPlaceScreen(
          prefilledDraft: place.toAddPlaceDraft(
            name: _displayName,
            address: _displayAddress,
            rating: _displayRating,
            priceRange: _displayPriceRange,
            openingHours: _displayOpeningHours,
            phone: _displayPhone,
            imageUrl: _displayImageUrl,
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

String? _firstNonBlank(
  String? primary, [
  String? fallback,
  String? secondFallback,
]) {
  for (final value in [primary, fallback, secondFallback]) {
    if (value == null) continue;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
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

/// Tappable row for phone / website. Tap → open, long-press → copy.
class _TappableDetailRow extends StatelessWidget {
  const _TappableDetailRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã sao chép'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
