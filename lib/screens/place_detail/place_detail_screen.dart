import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/place.dart';
import '../../providers/place_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/section_title.dart';
import '../../widgets/map_preview.dart';

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({super.key, required this.place});

  final Place place;

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late Future<Place> _placeFuture;

  @override
  void initState() {
    super.initState();
    _placeFuture = context.read<PlaceProvider>().getPlaceById(widget.place.id);
  }

  void _showFutureSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setReminder(BuildContext context, Place place) async {
    final now = DateTime.now();
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (selectedTime == null || !context.mounted) return;

    var visitDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!visitDateTime.isAfter(now)) {
      visitDateTime = visitDateTime.add(const Duration(days: 1));
    }

    final scheduleProvider = context.read<ScheduleProvider>();

    try {
      await scheduleProvider.createSchedule({
        'placeId': place.id,
        'date': _dateToApi(visitDateTime),
        'time': _timeToApi(visitDateTime),
        'status': 'UPCOMING',
        'hasReminder': true,
      });

      if (!context.mounted) return;
      _showFutureSnack(
        context,
        'Reminder set for ${_timeToApi(visitDateTime.subtract(const Duration(minutes: 30)))}',
      );
    } catch (error) {
      if (!context.mounted) return;
      _showFutureSnack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Place>(
      future: _placeFuture,
      initialData: widget.place,
      builder: (context, snapshot) {
        final place = snapshot.data ?? widget.place;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.88),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    place.safeImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.primarySoft,
                      child: const Icon(
                        Icons.place_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator(minHeight: 2),
                      if (snapshot.hasError) ...[
                        Text(
                          'Could not refresh place details',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: AppTextStyles.headline,
                            ),
                          ),
                          _Badge(label: place.category),
                        ],
                      ),
                      const SizedBox(height: 10),
                      RatingStars(rating: place.rating),
                      const SizedBox(height: 24),
                      const SectionTitle(
                        title: 'Overview',
                        icon: Icons.info_rounded,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        children: [
                          if (place.hasPriceRange)
                            _InfoRow(
                              icon: Icons.payments_rounded,
                              title: 'Price range',
                              value: place.priceRange,
                            ),
                          _InfoRow(
                            icon: Icons.location_on_rounded,
                            title: 'Address',
                            value: place.address,
                          ),
                        ],
                      ),
                      if (place.hasOpeningHours ||
                          place.hasPhone ||
                          place.hasMapsUrl) ...[
                        const SizedBox(height: 22),
                        const SectionTitle(
                          title: 'Visit information',
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            if (place.hasOpeningHours)
                              _InfoRow(
                                icon: Icons.access_time_rounded,
                                title: 'Opening hours',
                                value: place.openingHours,
                              ),
                            if (place.hasPhone)
                              _InfoRow(
                                icon: Icons.phone_rounded,
                                title: 'Phone',
                                value: place.safePhone,
                              ),
                            if (place.hasMapsUrl)
                              _InfoRow(
                                icon: Icons.map_rounded,
                                title: 'Google Maps',
                                value: place.safeMapsUrl,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      const SectionTitle(
                        title: 'Personal note',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: _cardDecoration(),
                        child: Text(place.safeNote, style: AppTextStyles.body),
                      ),
                      const SizedBox(height: 22),
                      const SectionTitle(
                        title: 'Location Preview',
                        icon: Icons.pin_drop_rounded,
                      ),
                      const SizedBox(height: 12),
                      MapPreview(place: place),
                      const SizedBox(height: 22),
                      const SectionTitle(
                        title: 'Actions',
                        icon: Icons.touch_app_rounded,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Open Google Maps',
                        icon: Icons.map_rounded,
                        onPressed: () async {
                          Uri? uri;
                          if (place.mapsUrl != null &&
                              place.mapsUrl!.isNotEmpty) {
                            uri = Uri.parse(place.mapsUrl!);
                          } else if (place.latitude != null &&
                              place.longitude != null) {
                            uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
                            );
                          }

                          if (uri != null) {
                            try {
                              final launched = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (launched) return;
                            } catch (_) {}
                          }

                          if (context.mounted) {
                            _showFutureSnack(
                              context,
                              'Could not open Google Maps',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Set Reminder',
                              icon: Icons.notifications_rounded,
                              secondary: true,
                              onPressed: () => _setReminder(context, place),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Add Calendar',
                              icon: Icons.event_rounded,
                              secondary: true,
                              onPressed: () => _showFutureSnack(
                                context,
                                'Calendar feature will be added later',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.border),
  );
}

String _dateToApi(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day';
}

String _timeToApi(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: 3),
                Text(value, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
