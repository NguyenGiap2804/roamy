import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/google_maps_urls.dart';
import '../../models/place.dart';
import '../../models/schedule.dart';
import '../../providers/place_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/section_title.dart';
import '../../widgets/map_preview.dart';
import '../../core/utils/snackbar_helper.dart';

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

  Future<void> _openSchedulePlanner(
    BuildContext context,
    Place place, {
    required bool reminderDefault,
  }) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final schedules = await scheduleProvider.getSchedulesSnapshot();
    if (!context.mounted) return;

    final matchingSchedules = schedules.where((schedule) {
      return schedule.placeId == place.id && schedule.status == 'UPCOMING';
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    final month = matchingSchedules.isEmpty
        ? DateTime(DateTime.now().year, DateTime.now().month)
        : DateTime(
            matchingSchedules.first.date.year,
            matchingSchedules.first.date.month,
          );
    final existing = matchingSchedules.where((schedule) {
      return schedule.placeId == place.id &&
          schedule.date.year == month.year &&
          schedule.date.month == month.month &&
          schedule.status == 'UPCOMING';
    }).toList();
    final hadExisting = existing.isNotEmpty;
    final seed = existing.isEmpty ? null : existing.first;

    final plan = await showModalBottomSheet<_SchedulePlan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SchedulePlannerSheet(
        reminderDefault: seed?.hasReminder ?? reminderDefault,
        initialMonth: month,
        initialDates: existing.map((schedule) => _dateOnly(schedule.date)),
        initialStart: seed == null
            ? const TimeOfDay(hour: 8, minute: 0)
            : _timeFromSchedule(seed),
        initialEnd: seed == null
            ? _endTimeFromOpeningHours(place.openingHours)
            : _endTimeFromSchedule(seed, place.openingHours),
      ),
    );

    if (plan == null || !context.mounted) return;

    final now = DateTime.now();
    final selected = plan.dates.map(_dateOnly).toSet();
    final existingByDay = {
      for (final schedule in existing) _dateOnly(schedule.date): schedule,
    };
    var changed = false;

    try {
      final tasks = <Future>[];

      for (final entry in existingByDay.entries) {
        if (!selected.contains(entry.key)) {
          tasks.add(
            scheduleProvider.deleteSchedule(
              entry.value.id,
              schedule: entry.value,
            ),
          );
          changed = true;
        }
      }

      for (final date in selected) {
        final startDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          plan.start.hour,
          plan.start.minute,
        );
        if (!startDateTime.isAfter(now)) continue;

        final payload = {
          'placeId': place.id,
          'date': _dateToApi(startDateTime),
          'time': _timeRangeToApi(plan.start, plan.end),
          'status': 'UPCOMING',
          'hasReminder': plan.hasReminder,
          'placeName': place.name,
          'category': place.category,
          'address': place.address,
          'openingHours': place.openingHours,
          'mapsUrl': place.mapsUrl,
          'latitude': place.latitude,
          'longitude': place.longitude,
        };

        final existingSchedule = existingByDay[_dateOnly(date)];
        if (existingSchedule == null) {
          tasks.add(
            _createScheduleWithFallback(scheduleProvider, payload, plan.start),
          );
          changed = true;
        } else {
          final timeChanged = existingSchedule.time != payload['time'];
          final reminderChanged =
              existingSchedule.hasReminder != payload['hasReminder'];

          if (timeChanged || reminderChanged) {
            tasks.add(
              _updateScheduleWithFallback(
                scheduleProvider,
                existingSchedule.id,
                payload,
                plan.start,
                currentSchedule: existingSchedule,
              ),
            );
            changed = true;
          }
        }
      }

      await Future.wait(tasks);

      if (!context.mounted) return;
      SnackBarHelper.showSuccess(
        context,
        changed
            ? (hadExisting ? 'Lưu thay đổi thành công' : 'Lưu thành công')
            : (selected.isNotEmpty
                  ? 'Không có thông tin được cập nhật'
                  : 'Không có thay đổi'),
      );
    } catch (error) {
      if (!context.mounted) return;
      SnackBarHelper.showError(context, error.toString());
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
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
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
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.3, 0.7, 1.0],
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                          'Không thể cập nhật chi tiết địa điểm',
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
                      RatingStars(
                        rating: place.rating,
                        textColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle(
                        title: 'Tổng quan',
                        icon: Icons.info_rounded,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        children: [
                          if (place.hasPriceRange)
                            _InfoRow(
                              icon: Icons.payments_rounded,
                              title: 'Khoảng giá',
                              value: place.priceRange,
                            ),
                          _InfoRow(
                            icon: Icons.location_on_rounded,
                            title: 'Địa chỉ',
                            value: place.address,
                          ),
                        ],
                      ),
                      if (place.hasOpeningHours ||
                          place.hasPhone ||
                          place.hasMapsUrl) ...[
                        const SizedBox(height: 22),
                        const SectionTitle(
                          title: 'Thông tin tham quan',
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            if (place.hasOpeningHours)
                              _InfoRow(
                                icon: Icons.access_time_rounded,
                                title: 'Giờ mở cửa',
                                value: place.openingHours,
                              ),
                            if (place.hasPhone)
                              _InfoRow(
                                icon: Icons.phone_rounded,
                                title: 'Điện thoại',
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
                        title: 'Ghi chú cá nhân',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: _cardDecoration(context),
                        child: Text(place.safeNote, style: AppTextStyles.body),
                      ),
                      const SizedBox(height: 22),
                      const SectionTitle(
                        title: 'Xem trước vị trí',
                        icon: Icons.pin_drop_rounded,
                      ),
                      const SizedBox(height: 12),
                      MapPreview(place: place),
                      const SizedBox(height: 22),
                      const SectionTitle(
                        title: 'Thao tác',
                        icon: Icons.touch_app_rounded,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Mở Google Maps',
                        icon: Icons.map_rounded,
                        onPressed: () async {
                          final uri = buildGoogleMapsLaunchUri(
                            mapsUrl: place.mapsUrl,
                            name: place.name,
                            address: place.address,
                            latitude: place.latitude,
                            longitude: place.longitude,
                          );

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
                            SnackBarHelper.showError(
                              context,
                              'Không thể mở bản đồ',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Nhắc nhở',
                              icon: Icons.notifications_rounded,
                              secondary: true,
                              onPressed: () => _openSchedulePlanner(
                                context,
                                place,
                                reminderDefault: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Lịch trình',
                              icon: Icons.event_rounded,
                              secondary: true,
                              onPressed: () => _openSchedulePlanner(
                                context,
                                place,
                                reminderDefault: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 24,
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

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Theme.of(context).dividerColor),
  );
}

String _dateToApi(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day';
}

String _timeToApi(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _timeRangeToApi(TimeOfDay start, TimeOfDay end) {
  return '${_timeToApi(start)}-${_timeToApi(end)}';
}

Future<void> _createScheduleWithFallback(
  ScheduleProvider provider,
  Map<String, dynamic> payload,
  TimeOfDay start,
) async {
  try {
    await provider.createSchedule(payload);
  } catch (_) {
    await provider.createSchedule({...payload, 'time': _timeToApi(start)});
  }
}

Future<void> _updateScheduleWithFallback(
  ScheduleProvider provider,
  String id,
  Map<String, dynamic> payload,
  TimeOfDay start, {
  Schedule? currentSchedule,
}) async {
  try {
    await provider.updateSchedule(
      id,
      payload,
      currentSchedule: currentSchedule,
    );
  } catch (_) {
    await provider.updateSchedule(id, {
      ...payload,
      'time': _timeToApi(start),
    }, currentSchedule: currentSchedule);
  }
}

TimeOfDay _timeFromSchedule(dynamic schedule) {
  final start = (schedule.time as String).split('-').first.trim();
  return _timeOfDayFromString(start) ?? const TimeOfDay(hour: 8, minute: 0);
}

TimeOfDay _endTimeFromSchedule(dynamic schedule, String openingHours) {
  final time = schedule.time as String;
  final source = time.contains('-')
      ? time.split('-').last.trim()
      : _openingHoursRange(openingHours)?.$2;
  if (source == null) return const TimeOfDay(hour: 17, minute: 0);
  return _timeOfDayFromString(source) ?? const TimeOfDay(hour: 17, minute: 0);
}

TimeOfDay _endTimeFromOpeningHours(String openingHours) {
  final source = _openingHoursRange(openingHours)?.$2;
  if (source == null) return const TimeOfDay(hour: 17, minute: 0);
  return _timeOfDayFromString(source) ?? const TimeOfDay(hour: 17, minute: 0);
}

(String, String)? _openingHoursRange(String? openingHours) {
  if (openingHours == null) return null;
  final match = RegExp(
    r'(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})',
  ).firstMatch(openingHours);
  if (match == null) return null;
  return (match.group(1)!, match.group(2)!);
}

TimeOfDay? _timeOfDayFromString(String value) {
  final parts = value.trim().split(':');
  if (parts.isEmpty) return null;
  final hour = int.tryParse(parts.first);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

class _SchedulePlan {
  const _SchedulePlan({
    required this.dates,
    required this.start,
    required this.end,
    required this.hasReminder,
  });

  final List<DateTime> dates;
  final TimeOfDay start;
  final TimeOfDay end;
  final bool hasReminder;
}

class _SchedulePlannerSheet extends StatefulWidget {
  const _SchedulePlannerSheet({
    required this.reminderDefault,
    required this.initialMonth,
    required this.initialDates,
    required this.initialStart,
    required this.initialEnd,
  });

  final bool reminderDefault;
  final DateTime initialMonth;
  final Iterable<DateTime> initialDates;
  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;

  @override
  State<_SchedulePlannerSheet> createState() => _SchedulePlannerSheetState();
}

class _SchedulePlannerSheetState extends State<_SchedulePlannerSheet> {
  late DateTime _month = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );
  late bool _hasReminder = widget.reminderDefault;
  late final Set<DateTime> _selectedDates = widget.initialDates
      .map(_dateOnly)
      .toSet();
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end = widget.initialEnd;
  int _step = 0;

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.xl,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        child: _step == 0 ? _buildDateStep(context) : _buildTimeStep(context),
      ),
    );
  }

  Widget _buildDateStep(BuildContext context) {
    final days = _daysInMonth(_month);
    final leadingBlanks = DateTime(_month.year, _month.month).weekday - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(
          title: 'Chọn ngày',
          subtitle: 'Đã chọn ${_selectedDates.length} ngày',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${_month.month}/${_month.year}',
                textAlign: TextAlign.center,
                style: AppTextStyles.title,
              ),
            ),
            IconButton(
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _weekdayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(label, style: AppTextStyles.caption),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leadingBlanks + days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(_month.year, _month.month, day);
            final normalized = _dateOnly(date);
            final selected = _selectedDates.contains(normalized);
            final disabled = normalized.isBefore(_dateOnly(DateTime.now()));

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: disabled
                  ? null
                  : () => setState(() {
                      if (selected) {
                        _selectedDates.remove(normalized);
                      } else {
                        _selectedDates.add(normalized);
                      }
                    }),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.primarySoft),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Opacity(
                  opacity: disabled ? 0.35 : 1,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Ngày trong tuần'),
              onPressed: () => _toggleByWeekday(includeWeekends: false),
            ),
            ActionChip(
              label: const Text('Cuối tuần'),
              onPressed: () => _toggleByWeekday(includeWeekends: true),
            ),
            ActionChip(
              label: const Text('Xóa'),
              onPressed: () => setState(_selectedDates.clear),
            ),
          ],
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Tiếp theo',
          icon: Icons.arrow_forward_rounded,
          onPressed: _selectedDates.isEmpty
              ? () {}
              : () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _buildTimeStep(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(
          title: 'Đặt thời gian tham quan',
          subtitle: 'Đã chọn ${_selectedDates.length} ngày',
          leading: IconButton(
            onPressed: () => setState(() => _step = 0),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: 12),
        _TimeTile(
          label: 'Bắt đầu',
          value: _start.format(context),
          onTap: () => _pickTime(isStart: true),
        ),
        _TimeTile(
          label: 'Kết thúc',
          value: _end.format(context),
          onTap: () => _pickTime(isStart: false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hasReminder,
          title: const Text('Nhắc nhở'),
          subtitle: const Text('Thông báo trước 30 phút và lúc bắt đầu'),
          onChanged: (value) => setState(() => _hasReminder = value),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Lưu lịch trình',
          icon: Icons.check_rounded,
          onPressed: () {
            if (!_endIsAfterStart) {
              SnackBarHelper.showError(
                context,
                'Giờ kết thúc phải sau giờ bắt đầu',
              );
              return;
            }

            final dates = _selectedDates.toList()..sort();
            Navigator.of(context).pop(
              _SchedulePlan(
                dates: dates,
                start: _start,
                end: _end,
                hasReminder: _hasReminder,
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _toggleByWeekday({required bool includeWeekends}) {
    final now = _dateOnly(DateTime.now());
    final days = _daysInMonth(_month);
    final dates = <DateTime>[];
    for (var day = 1; day <= days; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final normalized = _dateOnly(date);
      if (normalized.isBefore(now)) continue;
      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      if (includeWeekends == isWeekend) dates.add(normalized);
    }

    final allSelected =
        dates.isNotEmpty && dates.every(_selectedDates.contains);

    setState(() {
      if (allSelected) {
        _selectedDates.removeAll(dates);
      } else {
        _selectedDates.addAll(dates);
      }
    });
  }

  bool get _endIsAfterStart {
    return _end.hour * 60 + _end.minute > _start.hour * 60 + _start.minute;
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headline.copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTextStyles.subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
      title: Text(label),
      trailing: Text(value, style: AppTextStyles.title),
      onTap: onTap,
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _daysInMonth(DateTime month) {
  return DateTime(month.year, month.month + 1, 0).day;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.primary
              : AppColors.primaryDark,
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
      decoration: _cardDecoration(context),
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
