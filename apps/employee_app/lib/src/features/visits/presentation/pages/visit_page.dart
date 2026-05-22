import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../domain/entities/employee_visit.dart';
import '../viewmodels/visit_view_model.dart';

class VisitPage extends ConsumerStatefulWidget {
  const VisitPage({super.key});

  @override
  ConsumerState<VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends ConsumerState<VisitPage> {
  final Map<String, TextEditingController> _notesControllers = {};
  final _followUpController = TextEditingController();
  final _clientController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _fieldNotesController = TextEditingController();
  final _signatureKey = GlobalKey();
  final List<Offset?> _signaturePoints = [];
  String _selectedOutcome = 'Interested';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(visitViewModelProvider.notifier).loadVisits(),
    );
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _followUpController.dispose();
    _clientController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _fieldNotesController.dispose();
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitViewModelProvider);
    final visits = state.filteredVisits;
    final selected = visits.isEmpty ? null : visits.first;
    return AppShell(
      title: 'Visits',
      body: RefreshIndicator(
        onRefresh: () => ref.read(visitViewModelProvider.notifier).loadVisits(),
        child: ListView(
          children: [
            _Header(state: state),
            if (state.message != null)
              _Banner(text: state.message!, success: true),
            if (state.error != null)
              _Banner(
                text: state.error!.replaceFirst('Exception: ', ''),
                success: false,
              ),
            _SubmitFieldVisitCard(
              clientController: _clientController,
              contactController: _contactController,
              phoneController: _phoneController,
              addressController: _addressController,
              notesController: _fieldNotesController,
              loading: state.loading,
              onSubmit: _submitFieldVisit,
            ),
            const SizedBox(height: 14),
            _SearchAndFilters(state: state),
            const SizedBox(height: 12),
            Text(
              "TODAY'S VISITS",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            if (visits.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No visits match the current filters.'),
                ),
              ),
            ...visits.map(
              (visit) =>
                  _VisitCard(visit: visit, onTap: () => _openDetails(visit)),
            ),
            if (selected != null) ...[
              const SizedBox(height: 20),
              _VisitDetails(
                visit: selected,
                notesController: _controllerFor(selected),
                selectedOutcome: _selectedOutcome,
                onOutcomeChanged: (value) =>
                    setState(() => _selectedOutcome = value),
                onValidate: () async {
                  final text = await ref
                      .read(visitViewModelProvider.notifier)
                      .validateStart(selected);
                  if (context.mounted) _show(text);
                },
                onStart: () => ref
                    .read(visitViewModelProvider.notifier)
                    .startVisit(selected),
                onSaveNotes: () => ref
                    .read(visitViewModelProvider.notifier)
                    .saveNotes(
                      selected.id,
                      _controllerFor(selected).text.trim(),
                    ),
                onPhoto: (category) => ref
                    .read(visitViewModelProvider.notifier)
                    .capturePhoto(selected, category, context: context),
                onFollowUp: () => _addFollowUp(selected),
                onComplete: () => ref
                    .read(visitViewModelProvider.notifier)
                    .endVisit(
                      visit: selected,
                      notes: _controllerFor(selected).text.trim(),
                      outcome: _selectedOutcome,
                    ),
                signatureKey: _signatureKey,
                signaturePoints: _signaturePoints,
                onSignatureChanged: () => setState(() {}),
                onSaveSignature: () => _saveSignature(selected.id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitFieldVisit({required bool capturePhoto}) async {
    await ref
        .read(visitViewModelProvider.notifier)
        .submitFieldVisit(
          draft: FieldVisitDraft(
            clientName: _clientController.text.trim(),
            contactPerson: _contactController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            notes: _fieldNotesController.text.trim(),
          ),
          context: context,
          capturePhoto: capturePhoto,
        );
    final state = ref.read(visitViewModelProvider);
    if (state.error == null) {
      _clientController.clear();
      _contactController.clear();
      _phoneController.clear();
      _addressController.clear();
      _fieldNotesController.clear();
    }
  }

  TextEditingController _controllerFor(EmployeeVisit visit) {
    final controller = _notesControllers.putIfAbsent(
      visit.id,
      () => TextEditingController(text: visit.notes),
    );
    if (controller.text != visit.notes &&
        controller.selection.baseOffset <= 0) {
      controller.text = visit.notes;
    }
    return controller;
  }

  void _openDetails(EmployeeVisit visit) {
    _show('${visit.clientName}\n${visit.objective}\n${visit.siteAddress}');
  }

  Future<void> _addFollowUp(EmployeeVisit visit) async {
    await ref
        .read(visitViewModelProvider.notifier)
        .addFollowUp(
          visitId: visit.id,
          date: DateTime.now().add(const Duration(days: 2)),
          priority: visit.priority,
          notes: _followUpController.text.trim().isEmpty
              ? 'Follow-up required with ${visit.contactPerson}.'
              : _followUpController.text.trim(),
        );
    _followUpController.clear();
  }

  Future<void> _saveSignature(String visitId) async {
    final boundary =
        _signatureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || _signaturePoints.isEmpty) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) return;
    await ref
        .read(visitViewModelProvider.notifier)
        .uploadSignature(visitId, bytes);
    setState(_signaturePoints.clear);
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final VisitState state;

  @override
  Widget build(BuildContext context) {
    final completed = state.visits.where((v) => v.status == 'Completed').length;
    final active = state.visits.where((v) => v.status == 'In Progress').length;
    final score = state.visits.isEmpty
        ? 0
        : state.visits
                  .map((v) => v.productivityScore)
                  .reduce((a, b) => a + b) ~/
              state.visits.length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _Metric(label: 'Assigned', value: '${state.visits.length}'),
        _Metric(label: 'In Progress', value: '$active'),
        _Metric(label: 'Completed', value: '$completed'),
        _Metric(label: 'Score', value: '$score'),
      ],
    );
  }
}

class _SubmitFieldVisitCard extends StatelessWidget {
  const _SubmitFieldVisitCard({
    required this.clientController,
    required this.contactController,
    required this.phoneController,
    required this.addressController,
    required this.notesController,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController clientController;
  final TextEditingController contactController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController notesController;
  final bool loading;
  final Future<void> Function({required bool capturePhoto}) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUBMIT FIELD VISIT',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientController,
              decoration: const InputDecoration(
                labelText: 'Client / Company name',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact person',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address / site name',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Visit notes',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: loading
                      ? null
                      : () => onSubmit(capturePhoto: true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Capture Photo & Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchAndFilters extends ConsumerWidget {
  const _SearchAndFilters({required this.state});

  final VisitState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(visitViewModelProvider.notifier);
    return Column(
      children: [
        TextField(
          onChanged: notifier.setSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search client, contact or phone',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: state.statusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items:
                    const [
                          'All',
                          'Pending',
                          'In Progress',
                          'Completed',
                          'Missed',
                          'Cancelled',
                          'Rescheduled',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (value) => notifier.setStatusFilter(value ?? 'All'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: state.priorityFilter,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const ['All', 'Low', 'Medium', 'High', 'Critical']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (value) =>
                    notifier.setPriorityFilter(value ?? 'All'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.onTap});

  final EmployeeVisit visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visit.clientName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _Pill(
                    text: visit.priority,
                    color: _priorityColor(visit.priority),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${visit.contactPerson} • ${visit.phone}'),
              const SizedBox(height: 6),
              Text('${visit.visitType} • ${_time(visit.scheduledAt)}'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: visit.status, color: Colors.white24),
                  _Pill(
                    text: visit.distanceMeters == null
                        ? 'Distance --'
                        : '${visit.distanceMeters!.toStringAsFixed(0)} m',
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitDetails extends StatelessWidget {
  const _VisitDetails({
    required this.visit,
    required this.notesController,
    required this.selectedOutcome,
    required this.onOutcomeChanged,
    required this.onValidate,
    required this.onStart,
    required this.onSaveNotes,
    required this.onPhoto,
    required this.onFollowUp,
    required this.onComplete,
    required this.signatureKey,
    required this.signaturePoints,
    required this.onSignatureChanged,
    required this.onSaveSignature,
  });

  final EmployeeVisit visit;
  final TextEditingController notesController;
  final String selectedOutcome;
  final ValueChanged<String> onOutcomeChanged;
  final VoidCallback onValidate;
  final VoidCallback onStart;
  final VoidCallback onSaveNotes;
  final ValueChanged<String> onPhoto;
  final VoidCallback onFollowUp;
  final VoidCallback onComplete;
  final GlobalKey signatureKey;
  final List<Offset?> signaturePoints;
  final VoidCallback onSignatureChanged;
  final VoidCallback onSaveSignature;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VISIT DETAILS', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        _Section(
          title: 'Client Information',
          children: [
            _Info('Company', visit.clientName),
            _Info('Client Type', visit.clientType),
            _Info('Contact', visit.contactPerson),
            _Info('Phone', visit.phone),
            _Info('Email', visit.email.isEmpty ? '--' : visit.email),
            _Info('Address', visit.siteAddress),
            _Info('Category', visit.clientCategory),
          ],
        ),
        _Section(
          title: 'Visit Information',
          children: [
            _Info('Visit ID', visit.id),
            _Info('Assigned By', visit.assignedBy),
            _Info('Scheduled Time', _dateTime(visit.scheduledAt)),
            _Info('Priority', visit.priority),
            _Info('Status', visit.status),
            _Info('Objective', visit.objective),
            if (visit.duration != null)
              _Info('Visit Duration', _duration(visit.duration!)),
          ],
        ),
        _MapPreview(visit: visit),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onValidate,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Validate Start'),
            ),
            ElevatedButton.icon(
              onPressed: visit.isActive || visit.isCompleted ? null : onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Visit'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Site Evidence',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                        'Site Photo',
                        'Installation Area',
                        'Roof',
                        'Equipment',
                        'Meter',
                        'Customer Proof',
                        'Other',
                      ]
                      .map(
                        (category) => ActionChip(
                          avatar: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: Text(category),
                          onPressed: null,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Site Photo', 'Roof', 'Meter']
                  .map(
                    (category) => OutlinedButton(
                      onPressed: () => onPhoto(category),
                      child: Text(category),
                    ),
                  )
                  .toList(),
            ),
            Text(
              '${visit.photos.length} photos • ${visit.documents.length} documents • ${visit.audioNotes.length} voice notes',
            ),
          ],
        ),
        _Section(
          title: 'Visit Notes',
          children: [
            TextField(
              controller: notesController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Detailed notes / draft',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSaveNotes,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Notes'),
            ),
          ],
        ),
        _Section(
          title: 'Customer Signature',
          children: [
            RepaintBoundary(
              key: signatureKey,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final box =
                      signatureKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (box == null) return;
                  signaturePoints.add(
                    box.globalToLocal(details.globalPosition),
                  );
                  onSignatureChanged();
                },
                onPanEnd: (_) {
                  signaturePoints.add(null);
                  onSignatureChanged();
                },
                child: Container(
                  height: 150,
                  color: Colors.white,
                  child: CustomPaint(
                    painter: _SignaturePainter(signaturePoints),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSaveSignature,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Save Signature'),
            ),
          ],
        ),
        _Section(
          title: 'Outcome & Follow-up',
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedOutcome,
              decoration: const InputDecoration(labelText: 'Visit outcome'),
              items: const [
                'Interested',
                'Not Interested',
                'Follow-Up Required',
                'Quotation Sent',
                'Installation Approved',
                'Installation Completed',
                'Issue Resolved',
                'Service Completed',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) => onOutcomeChanged(value ?? 'Interested'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onFollowUp,
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('Create Follow-up'),
                ),
                ElevatedButton.icon(
                  onPressed: visit.isCompleted ? null : onComplete,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete Visit'),
                ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Client History & Timeline',
          children: [
            if (visit.activities.isEmpty && visit.followUps.isEmpty)
              const Text('No previous activity has been recorded yet.'),
            ...visit.activities.map(
              (activity) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(activity.message),
                subtitle: Text(_dateTime(activity.createdAt)),
              ),
            ),
            ...visit.followUps.map(
              (followUp) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${followUp.priority} follow-up'),
                subtitle: Text(
                  '${_dateTime(followUp.date)} • ${followUp.notes}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.visit});

  final EmployeeVisit visit;

  @override
  Widget build(BuildContext context) {
    final lat = visit.latitude ?? 28.6139;
    final lng = visit.longitude ?? 77.2090;
    return SizedBox(
      height: 210,
      child: FlutterMap(
        options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dooninfra.employee',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 42,
                height: 42,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '--' : value)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineLarge),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color),
      ),
      child: Text(text.toUpperCase(), style: theme.textTheme.labelSmall),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.success});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: success ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'Critical':
      return const Color(0xFFFF6B6B);
    case 'High':
      return Colors.white70;
    case 'Low':
      return Colors.white24;
    default:
      return Colors.white;
  }
}

String _time(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _dateTime(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${_time(date)}';
}

String _duration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}
