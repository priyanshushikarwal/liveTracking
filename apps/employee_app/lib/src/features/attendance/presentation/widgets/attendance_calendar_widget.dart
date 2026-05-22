import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AttendanceStatus { present, absent, leave, holiday, notMarked }

class AttendanceDay {
  final int day;
  final AttendanceStatus status;
  final DateTime date;

  AttendanceDay({required this.day, required this.status, required this.date});
}

class AttendanceCalendarWidget extends StatefulWidget {
  final DateTime currentMonth;
  final Map<int, AttendanceStatus> attendanceMap; // day -> status
  final Function(DateTime)? onDateTap;

  const AttendanceCalendarWidget({
    super.key,
    required this.currentMonth,
    required this.attendanceMap,
    this.onDateTap,
  });

  @override
  State<AttendanceCalendarWidget> createState() =>
      _AttendanceCalendarWidgetState();
}

class _AttendanceCalendarWidgetState extends State<AttendanceCalendarWidget> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(
      widget.currentMonth.year,
      widget.currentMonth.month,
    );
  }

  List<AttendanceDay> _generateCalendarDays() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);

    // Days from previous month to fill the first week
    final firstDayOfWeek = firstDay.weekday; // 1 = Monday, 7 = Sunday
    final daysFromPrevMonth = firstDayOfWeek - 1;

    final prevMonthLastDay = DateTime(
      _displayMonth.year,
      _displayMonth.month,
      0,
    );

    List<AttendanceDay> days = [];

    // Add previous month's days
    for (int i = daysFromPrevMonth - 1; i >= 0; i--) {
      final day = prevMonthLastDay.day - i;
      days.add(
        AttendanceDay(
          day: day,
          status: AttendanceStatus.notMarked,
          date: DateTime(prevMonthLastDay.year, prevMonthLastDay.month, day),
        ),
      );
    }

    // Add current month's days
    for (int i = 1; i <= lastDay.day; i++) {
      final status = widget.attendanceMap[i] ?? AttendanceStatus.notMarked;
      days.add(
        AttendanceDay(
          day: i,
          status: status,
          date: DateTime(_displayMonth.year, _displayMonth.month, i),
        ),
      );
    }

    // Add next month's days to fill the last week
    final remainingDays = 42 - days.length; // 6 weeks * 7 days
    for (int i = 1; i <= remainingDays; i++) {
      days.add(
        AttendanceDay(
          day: i,
          status: AttendanceStatus.notMarked,
          date: DateTime(_displayMonth.year, _displayMonth.month + 1, i),
        ),
      );
    }

    return days;
  }

  Color _getStatusColor(AttendanceStatus status, ThemeData theme) {
    switch (status) {
      case AttendanceStatus.present:
        return theme.colorScheme.primary;
      case AttendanceStatus.absent:
        return theme.colorScheme.error;
      case AttendanceStatus.leave:
        return theme.colorScheme.secondary;
      case AttendanceStatus.holiday:
        return theme.colorScheme.secondary;
      case AttendanceStatus.notMarked:
        return theme.colorScheme.outline;
    }
  }

  String _getStatusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.leave:
        return 'L';
      case AttendanceStatus.holiday:
        return 'H';
      case AttendanceStatus.notMarked:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _generateCalendarDays();
    final monthYear = DateFormat('MMMM yyyy').format(_displayMonth);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month header with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(monthYear.toUpperCase(), style: theme.textTheme.titleLarge),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _displayMonth = DateTime(
                          _displayMonth.year,
                          _displayMonth.month - 1,
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _displayMonth = DateTime(
                          _displayMonth.year,
                          _displayMonth.month + 1,
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekday headers
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => Center(
                    child: Text(day, style: theme.textTheme.labelSmall),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          // Calendar days grid
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: days
                .map(
                  (dayData) => GestureDetector(
                    onTap: () {
                      if (widget.onDateTap != null &&
                          dayData.date.month == _displayMonth.month) {
                        widget.onDateTap!(dayData.date);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: dayData.date.month == _displayMonth.month
                            ? _getStatusColor(dayData.status, theme)
                            : _getStatusColor(
                                dayData.status,
                                theme,
                              ).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${dayData.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    dayData.status == AttendanceStatus.notMarked
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.onPrimary,
                              ),
                            ),
                            if (dayData.status != AttendanceStatus.notMarked)
                              Text(
                                _getStatusLabel(dayData.status),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 16,
            children: [
              _buildLegendItem(context, 'P', AttendanceStatus.present),
              _buildLegendItem(context, 'A', AttendanceStatus.absent),
              _buildLegendItem(context, 'L', AttendanceStatus.leave),
              _buildLegendItem(context, 'H', AttendanceStatus.holiday),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    AttendanceStatus status,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _getStatusColor(status, theme),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label == 'P'
              ? 'Present'
              : label == 'A'
              ? 'Absent'
              : label == 'L'
              ? 'Leave'
              : 'Holiday',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
