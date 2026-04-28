import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate = DateTime.now();
  late final List<DateTime> _dates = List.generate(
    7,
    (index) => DateTime.now().add(Duration(days: index - 1)),
  );

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
    setState(() => _selectedDate = date);
    await context.read<ScheduleProvider>().fetchByDate(date);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, _) {
          final items = scheduleProvider.schedules;

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
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      final selected = _sameDay(date, _selectedDate);
                      final disabled = date.isBefore(
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
                  ...items.map((item) => _ScheduleCard(schedule: item)),
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
  const _ScheduleCard({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              schedule.time,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
          ),
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
