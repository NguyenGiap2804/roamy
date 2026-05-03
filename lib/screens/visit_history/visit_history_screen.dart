import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/schedule.dart';
import '../../providers/place_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../place_detail/place_detail_screen.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().fetchSchedules();
    });
  }

  Future<void> _openPlace(Schedule schedule) async {
    try {
      final place = await context.read<PlaceProvider>().getPlaceById(
        schedule.placeId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place)),
      );
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Could not open this place');
    }
  }

  Future<void> _openMaps(Schedule schedule) async {
    Uri? uri;
    if (schedule.hasMapsUrl) {
      uri = Uri.parse(schedule.mapsUrl!);
    } else if (schedule.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${schedule.latitude},${schedule.longitude}',
      );
    }

    if (uri == null) {
      SnackBarHelper.showError(context, 'No map link available');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    if (mounted) {
      SnackBarHelper.showError(context, 'Could not open Maps');
    }
  }

  Future<void> _visitAgain(Schedule schedule) async {
    final nextVisit = DateTime.now().add(const Duration(days: 7));
    final payload = {
      'placeId': schedule.placeId,
      'date': _dateToApi(nextVisit),
      'time': schedule.time,
      'status': scheduleStatusUpcoming,
      'hasReminder': schedule.hasReminder,
      'placeName': schedule.placeName,
      'category': schedule.category,
      'address': schedule.address,
      'openingHours': schedule.openingHours,
      'mapsUrl': schedule.mapsUrl,
      'latitude': schedule.latitude,
      'longitude': schedule.longitude,
    };

    try {
      await context.read<ScheduleProvider>().createSchedule(payload);
      if (!mounted) return;
      SnackBarHelper.showSuccess(context, 'Added a new visit next week');
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<ScheduleProvider>(
          builder: (context, provider, _) {
            final visits =
                provider.schedules
                    .where((schedule) => schedule.status == scheduleStatusDone)
                    .toList()
                  ..sort(
                    (a, b) => visitDateTimeForSchedule(
                      b,
                    ).compareTo(visitDateTimeForSchedule(a)),
                  );

            return RefreshIndicator(
              onRefresh: provider.fetchSchedules,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Visit history',
                          style: AppTextStyles.headline.copyWith(
                            color: _historyTextPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Places you have already marked as done.',
                    style: AppTextStyles.subtitle.copyWith(
                      color: _historyTextSecondary(context),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _VisitHistoryStats(visits: visits),
                  const SizedBox(height: 22),
                  if (provider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.errorMessage != null)
                    _HistoryError(
                      message: provider.errorMessage!,
                      onRetry: provider.fetchSchedules,
                    )
                  else if (visits.isEmpty)
                    const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No visits yet',
                      message:
                          'Mark a scheduled place as done and it will appear here.',
                    )
                  else
                    ...visits.map(
                      (visit) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _VisitHistoryCard(
                          schedule: visit,
                          onOpenPlace: () => _openPlace(visit),
                          onOpenMaps: () => _openMaps(visit),
                          onVisitAgain: () => _visitAgain(visit),
                        ),
                      ),
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

class _VisitHistoryStats extends StatelessWidget {
  const _VisitHistoryStats({required this.visits});

  final List<Schedule> visits;

  @override
  Widget build(BuildContext context) {
    final categories = visits.map((visit) => visit.displayCategory).toSet();
    final latest = visits.isEmpty ? null : visits.first;

    return Row(
      children: [
        Expanded(
          child: _HistoryStatCard(
            icon: Icons.check_circle_rounded,
            label: 'Completed',
            value: '${visits.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HistoryStatCard(
            icon: Icons.category_rounded,
            label: 'Categories',
            value: '${categories.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HistoryStatCard(
            icon: Icons.history_toggle_off_rounded,
            label: 'Latest',
            value: latest == null ? '-' : _shortDate(latest.date),
          ),
        ),
      ],
    );
  }
}

class _HistoryStatCard extends StatelessWidget {
  const _HistoryStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _historyCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              color: _historyTextPrimary(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: _historyTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitHistoryCard extends StatelessWidget {
  const _VisitHistoryCard({
    required this.schedule,
    required this.onOpenPlace,
    required this.onOpenMaps,
    required this.onVisitAgain,
  });

  final Schedule schedule;
  final VoidCallback onOpenPlace;
  final VoidCallback onOpenMaps;
  final VoidCallback onVisitAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _historyCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.displayPlaceName,
                      style: AppTextStyles.title.copyWith(
                        color: _historyTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(schedule.date)} at ${schedule.time}',
                      style: AppTextStyles.caption.copyWith(
                        color: _historyTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              _HistoryCategoryPill(label: schedule.displayCategory),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            schedule.displayAddress,
            style: AppTextStyles.body.copyWith(
              color: _historyTextPrimary(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenPlace,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Details'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onOpenMaps,
                icon: const Icon(Icons.map_rounded),
                tooltip: 'Open Maps',
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onVisitAgain,
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Visit again',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCategoryPill extends StatelessWidget {
  const _HistoryCategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.primary
              : AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _historyCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load visits',
            style: AppTextStyles.title.copyWith(
              color: _historyTextPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTextStyles.body.copyWith(
              color: _historyTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: () => onRetry(),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _historyCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Theme.of(context).dividerColor),
  );
}

Color _historyTextPrimary(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface;
}

Color _historyTextSecondary(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.white70
      : AppColors.textSecondary;
}

String _dateToApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _shortDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$day/$month';
}
