import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../models/nearby_place.dart';
import '../screens/add_place/add_place_screen.dart';

/// Bottom sheet that shows details of a [NearbyPlace].
///
/// Actions:
/// - Open in Google Maps
/// - Save to Roamy (navigate to AddPlaceScreen with pre-filled data)
class NearbyDetailSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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

            // Name
            Text(
              place.name,
              style: AppTextStyles.headline.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 12),

            // Category chip
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(icon: Icons.sell_rounded, label: place.category),
              ],
            ),
            const SizedBox(height: 14),

            // Address
            if (place.address.isNotEmpty)
              _DetailRow(
                icon: Icons.location_on_rounded,
                text: place.address,
              ),

            // Opening hours
            if (place.openingHours != null && place.openingHours!.isNotEmpty)
              _DetailRow(
                icon: Icons.schedule_rounded,
                text: place.openingHours!,
              ),

            // Phone
            if (place.phone != null && place.phone!.isNotEmpty)
              _DetailRow(
                icon: Icons.phone_rounded,
                text: place.phone!,
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(context),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Mở Google Maps'),
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
    final url = Uri.parse(place.mapsUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _saveToRoamy(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPlaceScreen(
          prefilledDraft: {
            'name': place.name,
            'address': place.address,
            'rating': place.rating,
            'latitude': place.latitude,
            'longitude': place.longitude,
            'mapsUrl': place.mapsUrl,
          },
        ),
      ),
    );
  }
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
          const SizedBox(width: 6),
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
