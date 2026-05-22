import 'package:flutter/material.dart';

class AttendanceStatistics {
  final int present;
  final int absent;
  final int leave;
  final int holiday;
  final int totalWorkingDays;
  final double attendancePercentage;
  final int currentStreak;

  AttendanceStatistics({
    required this.present,
    required this.absent,
    required this.leave,
    required this.holiday,
    required this.totalWorkingDays,
    required this.attendancePercentage,
    required this.currentStreak,
  });
}

class AttendanceStatisticsWidget extends StatelessWidget {
  final AttendanceStatistics statistics;

  const AttendanceStatisticsWidget({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
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
          Text('ATTENDANCE SUMMARY', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OVERALL ATTENDANCE',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${statistics.attendancePercentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.displayMedium,
                    ),
                  ],
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.scaffoldBackgroundColor,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: CustomPaint(
                      painter: AttendancePercentagePainter(
                        percentage: statistics.attendancePercentage,
                        trackColor: theme.colorScheme.outline,
                        progressColor: theme.colorScheme.primary,
                      ),
                      size: const Size(80, 80),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildStatCard(
                context,
                label: 'Present',
                value: '${statistics.present}',
                icon: Icons.check_circle,
              ),
              _buildStatCard(
                context,
                label: 'Absent',
                value: '${statistics.absent}',
                icon: Icons.cancel,
                warning: true,
              ),
              _buildStatCard(
                context,
                label: 'Leave',
                value: '${statistics.leave}',
                icon: Icons.event,
              ),
              _buildStatCard(
                context,
                label: 'Holiday',
                value: '${statistics.holiday}',
                icon: Icons.celebration,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_fire_department,
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT STREAK', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${statistics.currentStreak} days',
                      style: theme.textTheme.headlineLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL WORKING DAYS', style: theme.textTheme.labelLarge),
                Text(
                  '${statistics.totalWorkingDays}',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool warning = false,
  }) {
    final theme = Theme.of(context);
    final color = warning ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class AttendancePercentagePainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;

  AttendancePercentagePainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Draw progress arc
    final angle = (percentage / 100) * 2 * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      angle,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(AttendancePercentagePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
