import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../domain/entities/attendance_record.dart';
import '../viewmodels/attendance_view_model.dart';
import '../widgets/attendance_statistics_widget.dart';
import 'camera_capture_page.dart';
import 'selfie_preview_page.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  int selectedRadiusIndex = 0;
  bool _isLoadingCameras = true;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
    Future.microtask(
      () => ref.read(attendanceViewModelProvider.notifier).loadHistory(),
    );
  }

  Future<void> _initializeCameras() async {
    try {
      final cameras = await availableCameras();
      setState(() {
        _cameras = cameras;
        _isLoadingCameras = false;
      });
    } catch (e) {
      debugPrint('Error loading cameras: $e');
      setState(() => _isLoadingCameras = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceViewModelProvider);
    final active = state.activeRecord != null;

    return AppShell(
      title: 'Attendance',
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(attendanceViewModelProvider.notifier).loadHistory(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              _buildHeader(state),
              const SizedBox(height: 20),

              // Status card
              _buildStatusCard(state, active),
              const SizedBox(height: 20),

              // Current location card
              _buildLocationCard(state),
              const SizedBox(height: 20),

              // Mark attendance action button
              _buildMarkAttendanceButton(state),
              const SizedBox(height: 20),

              // Error/Success banner
              if (state.error != null) _buildErrorBanner(state.error!),
              if (state.message != null) _buildSuccessBanner(state.message!),
              const SizedBox(height: 20),

              // Last attendance card
              if (state.records.isNotEmpty)
                _buildLastAttendanceCard(state.records.first),
              const SizedBox(height: 20),

              // Calendar widget
              _buildCalendarSection(state),
              const SizedBox(height: 20),

              // Statistics widget
              _buildStatisticsSection(state),
              const SizedBox(height: 20),

              // Company notices
              _buildNoticesSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AttendanceState state) {
    final now = DateTime.now();
    final greeting = _getGreeting();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting.toUpperCase(), style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(
            '${now.day} ${_getMonthName(now.month)} ${now.year}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(_formatTime(now), style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AttendanceState state, bool active) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'ON DUTY' : 'READY FOR CHECK-IN',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  active
                      ? 'Since ${state.activeRecord?.checkInTime.hour}:${state.activeRecord?.checkInTime.minute.toString().padLeft(2, '0')}'
                      : 'Check in to start',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
              ),
              child: Center(
                child: Icon(
                  active ? Icons.check_circle : Icons.access_time,
                  color: theme.colorScheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(AttendanceState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('CURRENT LOCATION', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(state.readableLocation, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.my_location,
                  size: 12,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text('GPS Accuracy: --m', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAttendanceButton(AttendanceState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: state.loading || _isLoadingCameras || _cameras == null
              ? null
              : () => _startAttendanceFlow(state),
          child: state.loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  state.activeRecord == null
                      ? 'MARK CHECK-IN'
                      : 'MARK CHECK-OUT',
                ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _panelDecoration(context),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }

  Widget _buildLastAttendanceCard(AttendanceRecord record) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LAST ATTENDANCE', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check In: ${_formatDateTime(record.checkInTime)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (record.checkOutTime != null)
                      Text(
                        'Check Out: ${_formatDateTime(record.checkOutTime!)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: record.status.contains('CHECKED OUT')
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    record.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: record.status.contains('CHECKED OUT')
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(AttendanceState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ATTENDANCE CALENDAR', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Calendar widget placeholder',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(AttendanceState state) {
    final stats = AttendanceStatistics(
      present: state.records.where((r) => r.status.contains('CHECKED')).length,
      absent: 2,
      leave: 0,
      holiday: 0,
      totalWorkingDays: 22,
      attendancePercentage: 95.0,
      currentStreak: 8,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AttendanceStatisticsWidget(statistics: stats),
    );
  }

  Widget _buildNoticesSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTICES & UPDATES', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _panelDecoration(context),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maintain consistent attendance for incentives',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startAttendanceFlow(AttendanceState state) async {
    if (_cameras == null) return;

    try {
      final navigator = Navigator.of(context);

      // Prepare attendance record
      final notifier = ref.read(attendanceViewModelProvider.notifier);
      final verification = await notifier.prepareAttendance(
        attendanceType: state.activeRecord == null ? 'CHECK-IN' : 'CHECK-OUT',
        siteLatitude: AppConfig.defaultSiteLatitude,
        siteLongitude: AppConfig.defaultSiteLongitude,
        allowedRadius: AppConfig.attendanceAllowedRadii[selectedRadiusIndex],
      );

      if (!mounted) return;

      // Open camera
      final capturedFile = await navigator.push<File>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CameraCapturePage(cameras: _cameras!),
        ),
      );

      if (capturedFile == null) return;

      // Show preview
      final confirmed = await navigator.push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (previewContext) => SelfiePreviewPage(
            imageFile: capturedFile,
            onConfirm: () => Navigator.pop(previewContext, true),
            onRetake: () => Navigator.pop(previewContext, false),
          ),
        ),
      );

      if (!mounted || confirmed != true) return;

      // Submit attendance
      if (state.activeRecord == null) {
        await notifier.submitCheckIn(
          context: verification,
          selfiePath: capturedFile.path,
        );
      } else {
        await notifier.submitCheckOut(
          context: verification,
          selfiePath: capturedFile.path,
        );
      }
    } catch (e) {
      debugPrint('Error in attendance flow: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Theme.of(context).colorScheme.outline),
  );
}
