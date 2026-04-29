import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_title.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate = DateTime.now();
  late DateTime _month = DateTime(_selectedDate.year, _selectedDate.month);
  late int _selectedWeek = _weekOfMonth(_selectedDate);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().fetchByDate(_selectedDate);
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _month = DateTime(date.year, date.month);
      _selectedWeek = _weekOfMonth(date);
    });
    await context.read<ScheduleProvider>().fetchByDate(date);
  }

  Future<void> _changeMonth(int delta) async {
    final nextMonth = DateTime(_month.year, _month.month + delta);
    final firstVisible = _datesForWeek(
      nextMonth,
      1,
    ).firstWhere((date) => date.month == nextMonth.month);

    setState(() {
      _month = nextMonth;
      _selectedWeek = 1;
      _selectedDate = firstVisible;
    });
    await context.read<ScheduleProvider>().fetchByDate(firstVisible);
  }

  Future<void> _selectWeek(int week) async {
    final dates = _datesForWeek(_month, week);
    final target = dates.firstWhere((date) => date.month == _month.month);
    setState(() {
      _selectedWeek = week;
      _selectedDate = target;
    });
    await context.read<ScheduleProvider>().fetchByDate(target);
  }

  Future<void> _showScheduleQuickView(Schedule schedule) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ScheduleQuickView(
        schedule: schedule,
        onOpenMaps: () => _openScheduleMaps(context, schedule),
      ),
    );
  }

  Future<void> _openScheduleMaps(
    BuildContext context,
    Schedule schedule,
  ) async {
    Uri? uri;
    if (schedule.hasMapsUrl) {
      uri = Uri.parse(schedule.mapsUrl!);
    } else if (schedule.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${schedule.latitude},${schedule.longitude}',
      );
    }

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No map link available')));
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, _) {
          final items = scheduleProvider.schedules;
          final weekDates = _datesForWeek(_month, _selectedWeek);
          final weekCount = _weeksInMonth(_month);

          return RefreshIndicator(
            onRefresh: () => scheduleProvider.fetchByDate(_selectedDate),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text('Your Plans', style: AppTextStyles.headline),
                const SizedBox(height: 8),
                const Text(
                  'A simple planning view for upcoming visits.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
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
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: weekCount,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final week = index + 1;
                      final selected = week == _selectedWeek;
                      return ChoiceChip(
                        label: Text('Week $week'),
                        selected: selected,
                        onSelected: (_) => _selectWeek(week),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: weekDates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final date = weekDates[index];
                      final selected = _sameDay(date, _selectedDate);
                      final disabled =
                          date.month != _month.month ||
                          date.isBefore(
                            DateTime.now().subtract(const Duration(days: 1)),
                          );
                      return _DateTile(
                        date: date,
                        selected: selected,
                        disabled: disabled,
                        onTap: disabled ? null : () => _selectDate(date),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle(
                  title: 'Scheduled places',
                  icon: Icons.event_note_rounded,
                ),
                const SizedBox(height: 14),
                if (scheduleProvider.isLoading && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (scheduleProvider.errorMessage != null)
                  EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load plans',
                    message: scheduleProvider.errorMessage!,
                  )
                else if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No plans yet',
                    message: 'Scheduled visits will appear here.',
                  )
                else
                  ...items.map(
                    (item) => _ScheduleCard(
                      schedule: item,
                      onTap: () => _showScheduleQuickView(item),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Opacity(
          opacity: disabled ? 0.38 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _days[date.weekday - 1],
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onTap});

  final Schedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScheduleTimeBadge(schedule: schedule),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          schedule.displayPlaceName,
                          style: AppTextStyles.title.copyWith(fontSize: 17),
                        ),
                      ),
                      if (schedule.hasReminder)
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.orange,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${schedule.displayCategory} · ${schedule.displayAddress}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 10),
                  _StatusBadge(status: schedule.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTimeBadge extends StatelessWidget {
  const _ScheduleTimeBadge({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final times = _scheduleTimeParts(schedule);

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            times.$1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
            ),
          ),
          if (times.$2 != null) ...[
            Container(
              width: 2,
              height: 10,
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              times.$2!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleQuickView extends StatelessWidget {
  const _ScheduleQuickView({required this.schedule, required this.onOpenMaps});

  final Schedule schedule;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  schedule.displayPlaceName,
                  style: AppTextStyles.headline.copyWith(fontSize: 22),
                ),
              ),
              if (schedule.hasReminder)
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.orange,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Working hours',
            value: _displayScheduleTime(schedule),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Open Google Maps',
            icon: Icons.map_rounded,
            onPressed: onOpenMaps,
          ),
        ],
      ),
    );
  }
}

class _QuickInfoRow extends StatelessWidget {
  const _QuickInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 3),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'DONE' => AppColors.green,
      'CANCELLED' => AppColors.red,
      _ => AppColors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labelForStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _labelForStatus(String status) {
  return switch (status) {
    'DONE' => 'Done',
    'CANCELLED' => 'Cancelled',
    _ => 'Upcoming',
  };
}

String _displayScheduleTime(Schedule schedule) {
  final parts = _scheduleRawTimeParts(schedule);
  if (parts.$2 != null) {
    return _formatFriendlyRange(parts.$1, parts.$2!);
  }

  return _formatFriendlyTime(parts.$1);
}

(String, String?) _scheduleTimeParts(Schedule schedule) {
  final parts = _scheduleRawTimeParts(schedule);
  return (
    _formatBadgeTime(parts.$1),
    parts.$2 == null ? null : _formatBadgeTime(parts.$2!),
  );
}

(String, String?) _scheduleRawTimeParts(Schedule schedule) {
  final scheduleRange = _splitTimeRange(schedule.time);
  if (scheduleRange != null) return scheduleRange;

  final openingRange = _openingHoursRange(schedule.openingHours);
  if (openingRange != null) return (openingRange.$1, openingRange.$2);

  return (schedule.time, null);
}

(String, String)? _openingHoursRange(String? openingHours) {
  if (openingHours == null) return null;
  final match = RegExp(
    r'(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})',
  ).firstMatch(openingHours);
  if (match == null) return null;
  return (match.group(1)!, match.group(2)!);
}

(String, String)? _splitTimeRange(String value) {
  final parts = value.split(RegExp(r'\s*[-–]\s*'));
  if (parts.length < 2) return null;
  return (parts.first, parts[1]);
}

String _formatFriendlyRange(String start, String end) {
  return '${_formatFriendlyTime(start)} - ${_formatFriendlyTime(end)}h';
}

String _formatFriendlyTime(String value) {
  final parts = value.trim().split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  if (minute == 0) return '$hour';
  return '$hour:${minute.toString().padLeft(2, '0')}';
}

String _formatBadgeTime(String value) {
  final parts = value.trim().split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return '$hour:${minute.toString().padLeft(2, '0')}';
}

int _weekOfMonth(DateTime date) {
  final first = DateTime(date.year, date.month);
  return ((date.day + first.weekday - 2) ~/ 7) + 1;
}

int _weeksInMonth(DateTime month) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  final firstWeekday = DateTime(month.year, month.month).weekday;
  return ((days + firstWeekday - 2) ~/ 7) + 1;
}

List<DateTime> _datesForWeek(DateTime month, int week) {
  final first = DateTime(month.year, month.month);
  final start = first
      .subtract(Duration(days: first.weekday - 1))
      .add(Duration(days: (week - 1) * 7));
  return List.generate(7, (index) => start.add(Duration(days: index)));
}
