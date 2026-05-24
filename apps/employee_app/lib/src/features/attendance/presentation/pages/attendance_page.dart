import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../domain/entities/attendance_record.dart';
import '../viewmodels/attendance_view_model.dart';
import 'attendance_camera_page.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  int radius = AppConfig.attendanceAllowedRadii.first;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(attendanceViewModelProvider.notifier).loadHistory(),
    );
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
        child: ListView(
          children: [
            _HeroPanel(
              employeeName: 'Employee',
              designation: 'Field Workforce',
              state: state,
            ),
            const SizedBox(height: 14),
            _ReadinessGrid(state: state),
            const SizedBox(height: 14),
            _AttendanceCard(
              active: active,
              radius: radius,
              onRadiusChanged: (value) => setState(() => radius = value),
              onCheckIn: state.loading ? null : () => _runFlow('CHECK-IN'),
              onCheckOut: state.loading ? null : () => _runFlow('CHECK-OUT'),
            ),
            if (state.message != null) ...[
              const SizedBox(height: 12),
              _Banner(message: state.message!, positive: true),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              _Banner(message: state.error!, positive: false),
            ],
            const SizedBox(height: 18),
            Text(
              'Verification Timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...state.records.map((record) => _RecordTile(record: record)),
          ],
        ),
      ),
    );
  }

  Future<void> _runFlow(String type) async {
    final notifier = ref.read(attendanceViewModelProvider.notifier);
    
    // Check background permission before check-in
    if (type == 'CHECK-IN') {
      final locationService = ref.read(locationServiceProvider);
      final hasBackgroundPermission = await locationService.hasBackgroundPermission();
      
      if (!hasBackgroundPermission) {
        if (!mounted) return;
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const BackgroundPermissionPage(),
          ),
        );
        if (result != true) return;
      }
    }
    
    try {
      final verification = await notifier.prepareAttendance(
        attendanceType: type,
        siteLatitude: AppConfig.defaultSiteLatitude,
        siteLongitude: AppConfig.defaultSiteLongitude,
        allowedRadius: radius,
      );
      if (!mounted) return;
      final capture = await Navigator.of(context).push<AttendanceCapture>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AttendanceCameraPage(
            employeeName: 'Employee',
            locationName: verification.readableLocation,
            attendanceType: type,
            gpsAccuracy: verification.location.accuracy,
            companyName: 'DoonInfra Field Forces',
          ),
        ),
      );
      if (capture == null) return;
      if (type == 'CHECK-IN') {
        await notifier.submitCheckIn(
          context: verification,
          selfiePath: capture.localPath,
        );
      } else {
        await notifier.submitCheckOut(
          context: verification,
          selfiePath: capture.localPath,
        );
      }
    } catch (_) {
      // The view model has already surfaced the verification error.
    }
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.employeeName,
    required this.designation,
    required this.state,
  });

  final String employeeName;
  final String designation;
  final AttendanceState state;

  @override
  Widget build(BuildContext context) {
    final status = state.activeRecord == null
        ? 'Ready for Check-In'
        : 'On Duty';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(employeeName.characters.firstOrNull ?? 'E'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(designation),
                  ],
                ),
              ),
              Chip(label: Text(status.toUpperCase())),
            ],
          ),
          const SizedBox(height: 18),
          Text('Shift: 9:00 AM - 6:00 PM'),
          Text('Location: ${state.readableLocation}'),
          Text('Work Status: $status'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: state.activeRecord == null ? 0.08 : 0.58,
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}

class _ReadinessGrid extends StatelessWidget {
  const _ReadinessGrid({required this.state});

  final AttendanceState state;

  @override
  Widget build(BuildContext context) {
    final checks = [
      _ReadinessItem(
        'Internet',
        state.internetStatus,
        state.internetStatus != 'Offline',
      ),
      _ReadinessItem(
        'GPS',
        state.gpsEnabled ? 'Enabled' : 'Unavailable',
        state.gpsEnabled,
      ),
      _ReadinessItem(
        'Accuracy',
        state.highAccuracyReady ? 'High' : 'Checking',
        state.highAccuracyReady,
      ),
      _ReadinessItem(
        'Battery',
        '${state.batteryPercent}%',
        state.batteryPercent > 5,
      ),
      _ReadinessItem(
        'Security',
        state.securityTrusted ? 'Trusted' : 'Pending',
        state.securityTrusted,
      ),
      _ReadinessItem(
        'Sync Queue',
        '${state.pendingUploads}',
        state.pendingUploads == 0,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: checks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _ReadinessTile(item: checks[index]),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.active,
    required this.radius,
    required this.onRadiusChanged,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final bool active;
  final int radius;
  final ValueChanged<int> onRadiusChanged;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workforce Verification',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: radius,
              decoration: const InputDecoration(
                labelText: 'Allowed geo radius',
              ),
              items: AppConfig.attendanceAllowedRadii
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value meters'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => onRadiusChanged(value ?? radius),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: active ? null : onCheckIn,
                    icon: const Icon(Icons.login),
                    label: const Text('CHECK IN'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: active ? onCheckOut : null,
                    icon: const Icon(Icons.logout),
                    label: const Text('CHECK OUT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.verificationStatus == 'VERIFIED'
        ? Theme.of(context).colorScheme.primary
        : record.verificationStatus == 'QUEUED'
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(Icons.verified_user, color: color),
        ),
        title: Text(record.displayLocation),
        subtitle: Text(
          '${record.status} | ${_time(record.checkInTime)} | ${record.syncStatus}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${record.confidenceScore}%'),
            Text(
              record.riskLevel,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : value.hour;
    final labelHour = hour == 0 ? 12 : hour;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${labelHour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _ReadinessTile extends StatelessWidget {
  const _ReadinessTile({required this.item});

  final _ReadinessItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: item.ok
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(item.ok ? Icons.check_circle : Icons.pending, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.positive});

  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: positive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

class _ReadinessItem {
  const _ReadinessItem(this.label, this.value, this.ok);

  final String label;
  final String value;
  final bool ok;
}

/// Background Permission Request Page
/// Shown when employee tries to check in without background location permission
class BackgroundPermissionPage extends StatefulWidget {
  const BackgroundPermissionPage({super.key});

  @override
  State<BackgroundPermissionPage> createState() => _BackgroundPermissionPageState();
}

class _BackgroundPermissionPageState extends State<BackgroundPermissionPage> {
  bool _checking = false;

  Future<void> _requestPermission() async {
    setState(() => _checking = true);
    
    // Open app settings to allow user to enable background permission
    await Geolocator.openAppSettings();
    
    setState(() => _checking = false);
  }

  Future<void> _checkPermission() async {
    setState(() => _checking = true);
    
    final permission = await Geolocator.checkPermission();
    final hasBackground = permission == LocationPermission.always;
    
    setState(() => _checking = false);
    
    if (hasBackground && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D992).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: Color(0xFF00D992),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Background Tracking Required',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Description
              const Text(
                'Your company requires location tracking during working hours.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Benefits
              _buildBenefitItem(
                Icons.verified_user,
                'Verify attendance',
                'Confirm you are at assigned locations',
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                Icons.map,
                'Monitor field activity',
                'Managers can see real-time work progress',
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                Icons.route,
                'Record travel distance',
                'Automatic mileage and route tracking',
              ),
              const Spacer(),
              // Permission instruction
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF00D992), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'How to enable:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1. Tap "Open Settings" below'),
                    _buildStep('2. Select "Location"'),
                    _buildStep('3. Choose "Allow all the time"'),
                    _buildStep('4. Return to this app'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _checking ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D992),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Open Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _checking ? null : _checkPermission,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'I have enabled it - Continue',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel Check-In',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF00D992)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
