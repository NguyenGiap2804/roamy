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
import '../../core/utils/snackbar_helper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate = DateTime.now();
  late DateTime _month = DateTime(_selectedDate.year, _selectedDate.month);
  late int _selectedWeek = _weekOfMonth(_selectedDate);
  _ScheduleStatusFilter _statusFilter = _ScheduleStatusFilter.all;

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
    final screenContext = context;
    await showModalBottomSheet<void>(
      context: screenContext,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ScheduleQuickView(
        schedule: schedule,
        onOpenMaps: () => _openScheduleMaps(screenContext, schedule),
        onQuickEdit: !schedule.isPendingSync
            ? () => _openScheduleQuickEdit(sheetContext, schedule)
            : null,
        onMarkDone: schedule.isUpcoming && !schedule.isPendingSync
            ? () => _changeScheduleStatus(
                sheetContext,
                schedule,
                scheduleStatusDone,
              )
            : null,
        onCancelSchedule: schedule.isUpcoming && !schedule.isPendingSync
            ? () => _changeScheduleStatus(
                sheetContext,
                schedule,
                scheduleStatusCancelled,
              )
            : null,
        onReopenSchedule: !schedule.isUpcoming && !schedule.isPendingSync
            ? () => _changeScheduleStatus(
                sheetContext,
                schedule,
                scheduleStatusUpcoming,
              )
            : null,
      ),
    );
  }

  Future<void> _changeScheduleStatus(
    BuildContext sheetContext,
    Schedule schedule,
    String status,
  ) async {
    Navigator.of(sheetContext).pop();

    try {
      await context.read<ScheduleProvider>().updateScheduleStatus(
        schedule.id,
        status,
        currentSchedule: schedule,
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(context, _statusActionSuccessMessage(status));
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(context, error.toString());
    }
  }

  Future<void> _openScheduleQuickEdit(
    BuildContext sheetContext,
    Schedule schedule,
  ) async {
    Navigator.of(sheetContext).pop();

    final result = await showModalBottomSheet<_ScheduleQuickEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ScheduleQuickEditSheet(schedule: schedule),
    );

    if (!mounted || result == null) return;

    final payload = {
      'time': result.end == null
          ? _timeToApi(result.start)
          : _timeRangeToApi(result.start, result.end!),
      'hasReminder': result.hasReminder,
    };

    final hasChanged =
        schedule.time != payload['time'] ||
        schedule.hasReminder != result.hasReminder;

    if (!hasChanged) {
      SnackBarHelper.showSuccess(context, 'Khong co thay doi');
      return;
    }

    try {
      await _updateScheduleWithFallback(
        context.read<ScheduleProvider>(),
        schedule.id,
        payload,
        result.start,
        currentSchedule: schedule,
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(context, 'Da cap nhat lich trinh');
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(context, error.toString());
    }
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
      SnackBarHelper.showError(context, 'Không có liên kết bản đồ');
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
      SnackBarHelper.showError(context, 'Không thể mở bản đồ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, _) {
          final items = scheduleProvider.schedules;
          final filteredItems = _filterSchedules(items);
          final weekDates = _datesForWeek(_month, _selectedWeek);
          final weekCount = _weeksInMonth(_month);

          return RefreshIndicator(
            onRefresh: () => scheduleProvider.fetchByDate(_selectedDate),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text('Kế hoạch của bạn', style: AppTextStyles.headline),
                const SizedBox(height: 8),
                const Text(
                  'Xem danh sách kế hoạch sắp tới.',
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
                        label: Text('Tuần $week'),
                        selected: selected,
                        onSelected: (_) => _selectWeek(week),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: Theme.of(context).colorScheme.surface,
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
                  title: 'Địa điểm đã lên lịch',
                  icon: Icons.event_note_rounded,
                ),
                if (scheduleProvider.hasPendingSync) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Dang dong bo lich trinh...',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _ScheduleStatusFilter.values.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _ScheduleStatusFilter.values[index];
                      final selected = filter == _statusFilter;
                      return ChoiceChip(
                        label: Text(
                          '${_labelForFilter(filter)} (${_countForFilter(items, filter)})',
                        ),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = filter;
                          });
                        },
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      );
                    },
                  ),
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
                    title: 'Không thể tải kế hoạch',
                    message: scheduleProvider.errorMessage!,
                  )
                else if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'Chưa có kế hoạch nào',
                    message: 'Các địa điểm bạn lên lịch sẽ hiển thị tại đây.',
                  )
                else if (filteredItems.isEmpty)
                  EmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'Khong co lich phu hop',
                    message:
                        'Thu bo loc ${_labelForFilter(_statusFilter).toLowerCase()} hoac chon ngay khac.',
                  )
                else
                  ...filteredItems.map(
                    (item) => _ScheduleCard(
                      schedule: item,
                      onTap: () => _showScheduleQuickView(item),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Schedule> _filterSchedules(List<Schedule> schedules) {
    return schedules.where((schedule) {
      return switch (_statusFilter) {
        _ScheduleStatusFilter.all => true,
        _ScheduleStatusFilter.upcoming => schedule.isUpcoming,
        _ScheduleStatusFilter.done => schedule.isDone,
        _ScheduleStatusFilter.cancelled => schedule.isCancelled,
      };
    }).toList();
  }

  int _countForFilter(List<Schedule> schedules, _ScheduleStatusFilter filter) {
    return schedules.where((schedule) {
      return switch (filter) {
        _ScheduleStatusFilter.all => true,
        _ScheduleStatusFilter.upcoming => schedule.isUpcoming,
        _ScheduleStatusFilter.done => schedule.isDone,
        _ScheduleStatusFilter.cancelled => schedule.isCancelled,
      };
    }).length;
  }
}

enum _ScheduleStatusFilter { all, upcoming, done, cancelled }

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

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).dividerColor,
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
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
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
                      if (schedule.isPendingSync)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sync',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
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
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            times.$1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.primary
                  : AppColors.primaryDark,
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
              style: TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.primary
                    : AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleQuickView extends StatelessWidget {
  const _ScheduleQuickView({
    required this.schedule,
    required this.onOpenMaps,
    this.onQuickEdit,
    this.onMarkDone,
    this.onCancelSchedule,
    this.onReopenSchedule,
  });

  final Schedule schedule;
  final VoidCallback onOpenMaps;
  final VoidCallback? onQuickEdit;
  final VoidCallback? onMarkDone;
  final VoidCallback? onCancelSchedule;
  final VoidCallback? onReopenSchedule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 10),
            _StatusBadge(status: schedule.status),
            const SizedBox(height: 16),
            _QuickInfoRow(
              icon: Icons.event_rounded,
              label: 'Ngay',
              value: _formatScheduleDate(schedule.date),
            ),
            const SizedBox(height: 12),
            _QuickInfoRow(
              icon: Icons.schedule_rounded,
              label: 'Giờ hoạt động',
              value: _displayScheduleTime(schedule),
            ),
            const SizedBox(height: 12),
            _QuickInfoRow(
              icon: Icons.location_on_rounded,
              label: 'Dia diem',
              value: schedule.displayAddress,
            ),
            const SizedBox(height: 18),
            if (schedule.isPendingSync) ...[
              Text(
                'Dang dong bo thay doi...',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              PrimaryButton(
                label: 'Chinh nhanh',
                icon: Icons.edit_calendar_rounded,
                secondary: true,
                onPressed: onQuickEdit!,
              ),
              const SizedBox(height: 10),
            ],
            if (!schedule.isPendingSync && schedule.isUpcoming) ...[
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Da di xong',
                      icon: Icons.check_circle_rounded,
                      secondary: true,
                      onPressed: onMarkDone!,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 53,
                      child: FilledButton.icon(
                        onPressed: onCancelSchedule,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 19),
                        label: const Text('Huy lich'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ] else if (!schedule.isPendingSync) ...[
              PrimaryButton(
                label: 'Mo lai lich',
                icon: Icons.refresh_rounded,
                secondary: true,
                onPressed: onReopenSchedule!,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Mở Google Maps',
              icon: Icons.map_rounded,
              onPressed: onOpenMaps,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleQuickEditResult {
  const _ScheduleQuickEditResult({
    required this.start,
    required this.end,
    required this.hasReminder,
  });

  final TimeOfDay start;
  final TimeOfDay? end;
  final bool hasReminder;
}

class _ScheduleQuickEditSheet extends StatefulWidget {
  const _ScheduleQuickEditSheet({required this.schedule});

  final Schedule schedule;

  @override
  State<_ScheduleQuickEditSheet> createState() =>
      _ScheduleQuickEditSheetState();
}

class _ScheduleQuickEditSheetState extends State<_ScheduleQuickEditSheet> {
  late TimeOfDay _start = _timeFromScheduleStart(widget.schedule);
  late TimeOfDay? _end = _endTimeFromScheduleIfAny(widget.schedule);
  late bool _hasReminder = widget.schedule.hasReminder;

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chinh nhanh',
              style: AppTextStyles.headline.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.schedule.displayPlaceName} • ${_formatScheduleDate(widget.schedule.date)}',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 10),
            _StatusBadge(status: widget.schedule.status),
            const SizedBox(height: 16),
            _QuickEditTimeTile(
              label: 'Bat dau',
              value: _start.format(context),
              onTap: () => _pickTime(isStart: true),
            ),
            _QuickEditTimeTile(
              label: 'Ket thuc',
              value: _end?.format(context) ?? 'Khong dat',
              onTap: () => _pickTime(isStart: false),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_end == null)
                  ActionChip(
                    label: const Text('Them gio ket thuc'),
                    onPressed: () => _pickTime(isStart: false),
                  )
                else
                  ActionChip(
                    label: const Text('Bo gio ket thuc'),
                    onPressed: () => setState(() => _end = null),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasReminder,
              title: const Text('Nhac nho'),
              subtitle: Text(
                widget.schedule.isUpcoming
                    ? 'Thong bao truoc 30 phut va luc bat dau'
                    : 'Se co hieu luc khi lich tro lai Upcoming',
              ),
              onChanged: (value) => setState(() => _hasReminder = value),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Luu thay doi',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? _start
          : (_end ?? _defaultQuickEditEndTime(_start)),
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

  void _submit() {
    if (_end != null && !_isEndAfterStart(_start, _end!)) {
      SnackBarHelper.showError(context, 'Gio ket thuc phai sau gio bat dau');
      return;
    }

    Navigator.of(context).pop(
      _ScheduleQuickEditResult(
        start: _start,
        end: _end,
        hasReminder: _hasReminder,
      ),
    );
  }
}

class _QuickEditTimeTile extends StatelessWidget {
  const _QuickEditTimeTile({
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
      scheduleStatusDone => AppColors.green,
      scheduleStatusCancelled => AppColors.red,
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
    scheduleStatusDone => 'Done',
    scheduleStatusCancelled => 'Cancelled',
    _ => 'Upcoming',
  };
}

String _labelForFilter(_ScheduleStatusFilter filter) {
  return switch (filter) {
    _ScheduleStatusFilter.all => 'Tat ca',
    _ScheduleStatusFilter.upcoming => 'Upcoming',
    _ScheduleStatusFilter.done => 'Done',
    _ScheduleStatusFilter.cancelled => 'Cancelled',
  };
}

String _statusActionSuccessMessage(String status) {
  return switch (status) {
    scheduleStatusDone => 'Da danh dau da di xong',
    scheduleStatusCancelled => 'Da huy lich trinh',
    _ => 'Da mo lai lich trinh',
  };
}

String _formatScheduleDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String _timeToApi(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _timeRangeToApi(TimeOfDay start, TimeOfDay end) {
  return '${_timeToApi(start)}-${_timeToApi(end)}';
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

TimeOfDay _timeFromScheduleStart(Schedule schedule) {
  final value = _scheduleRawTimeParts(schedule).$1;
  return _timeOfDayFromString(value) ?? const TimeOfDay(hour: 8, minute: 0);
}

TimeOfDay? _endTimeFromScheduleIfAny(Schedule schedule) {
  final range = _splitTimeRange(schedule.time);
  if (range == null) return null;
  return _timeOfDayFromString(range.$2);
}

TimeOfDay _defaultQuickEditEndTime(TimeOfDay start) {
  final totalMinutes = start.hour * 60 + start.minute + 60;
  final clampedMinutes = totalMinutes >= 24 * 60
      ? (23 * 60) + 59
      : totalMinutes;
  return TimeOfDay(hour: clampedMinutes ~/ 60, minute: clampedMinutes % 60);
}

TimeOfDay? _timeOfDayFromString(String value) {
  final parts = value.trim().split(':');
  if (parts.isEmpty) return null;

  final hour = int.tryParse(parts.first);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (hour == null || minute == null) return null;

  return TimeOfDay(hour: hour, minute: minute);
}

bool _isEndAfterStart(TimeOfDay start, TimeOfDay end) {
  return (end.hour * 60) + end.minute > (start.hour * 60) + start.minute;
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
