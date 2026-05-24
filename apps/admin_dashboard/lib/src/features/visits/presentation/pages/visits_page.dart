import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/widgets/admin_shell.dart';

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  List<Map<String, dynamic>> _visits = const [];
  List<Map<String, dynamic>> _employees = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = supabase
        .from('visits')
        .stream(primaryKey: ['id'])
        .listen((_) => _load());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('visits')
          .select(
            '*, clients(*), visit_photos(*), visit_notes(*), visit_documents(*), visit_audio_notes(*), visit_signatures(*), visit_followups!visit_followups_visit_id_fkey(*), visit_activities(*), visit_outcomes(*)',
          )
          .order('scheduled_at', ascending: true);
      final employeeRows = await supabase
          .from('profiles')
          .select(
            'id, auth_user_id, employee_id, full_name, email, role, organization_id, meta',
          )
          .ilike('role', 'employee')
          .order('full_name', ascending: true);
      if (!mounted) return;
      setState(() {
        _visits = (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _employees = (employeeRows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
        _visits = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _VisitStats(_visits);
    return AdminShell(
      currentLocation: '/visits',
      title: 'Visits',
      body: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'EMPLOYEE SUBMITTED VISITS',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Using local visit preview: $_error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 6 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _Metric(label: 'Total', value: '${stats.total}'),
              _Metric(label: 'Pending', value: '${stats.pending}'),
              _Metric(label: 'In Progress', value: '${stats.active}'),
              _Metric(label: 'Completed', value: '${stats.completed}'),
              _Metric(label: 'Missed', value: '${stats.missed}'),
              _Metric(label: 'Conversion', value: '${stats.conversionRate}%'),
            ],
          ),
          const SizedBox(height: 18),
          _VisitMapPanel(
            visits: _visits,
            employees: _employees,
            loading: _loading,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 980;
              final table = _VisitTable(
                visits: _visits,
                employees: _employees,
                loading: _loading,
                onEdit: _showEditVisit,
                onCancel: _cancelVisit,
                onViewPhotos: _showVisitPhotos,
              );
              final side = Column(
                children: [
                  _AnalyticsPanel(stats: stats, visits: _visits),
                  const SizedBox(height: 14),
                  _VisitEvidencePanel(visits: _visits),
                ],
              );
              if (!wide) {
                return Column(
                  children: [table, const SizedBox(height: 14), side],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: table),
                  const SizedBox(width: 14),
                  Expanded(child: side),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _EmployeePerformance(visits: _visits, employees: _employees),
        ],
      ),
    );
  }

  Future<void> _showEditVisit(Map<String, dynamic> visit) async {
    await _showVisitDialog(visit: visit);
  }

  Future<void> _showVisitPhotos(Map<String, dynamic> visit) async {
    final photosFuture = _loadVisitPhotos(visit);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_clientName(visit)} Proof Photos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: photosFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final photos = snapshot.data ?? const [];
                      if (photos.isEmpty) {
                        return const Center(
                          child: Text(
                            'No proof photo uploaded for this visit.',
                          ),
                        );
                      }
                      return GridView.builder(
                        itemCount: photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 280,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.82,
                            ),
                        itemBuilder: (context, index) =>
                            _PhotoTile(photo: photos[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadVisitPhotos(
    Map<String, dynamic> visit,
  ) async {
    final photos = [..._photos(visit)];
    final knownPaths = photos
        .map((photo) => photo['storage_path']?.toString())
        .whereType<String>()
        .toSet();
    final visitId = visit['id']?.toString() ?? '';
    if (visitId.isEmpty) return photos;

    try {
      final objects = await supabase.storage
          .from('visit-media')
          .list(path: 'photos/$visitId');
      for (final object in objects) {
        final name = object.name;
        if (name.isEmpty) continue;
        final path = 'photos/$visitId/$name';
        if (knownPaths.contains(path)) continue;
        photos.add({
          'category': 'Visit Photo',
          'storage_path': path,
          'public_url': supabase.storage.from('visit-media').getPublicUrl(path),
          'readable_location':
              '${_lat(visit)?.toStringAsFixed(5) ?? '--'}, ${_lng(visit)?.toStringAsFixed(5) ?? '--'}',
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load bucket photos: $error')),
        );
      }
    }

    return _withSignedPhotoUrls(photos);
  }

  Future<List<Map<String, dynamic>>> _withSignedPhotoUrls(
    List<Map<String, dynamic>> photos,
  ) async {
    final resolved = <Map<String, dynamic>>[];
    for (final photo in photos) {
      final next = Map<String, dynamic>.from(photo);
      final storagePath = next['storage_path']?.toString();
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          next['display_url'] = await supabase.storage
              .from('visit-media')
              .createSignedUrl(storagePath, 60 * 60);
        } catch (_) {
          next['display_url'] = supabase.storage
              .from('visit-media')
              .getPublicUrl(storagePath);
        }
      }
      resolved.add(next);
    }
    return resolved;
  }

  Future<void> _showVisitDialog({Map<String, dynamic>? visit}) async {
    final client = TextEditingController(
      text: visit?['client_name'] as String? ?? '',
    );
    final objective = TextEditingController(
      text: visit?['objective'] as String? ?? 'Client Visit',
    );
    final address = TextEditingController(
      text: visit?['site_address'] as String? ?? '',
    );
    var priority = (visit?['priority'] as String? ?? 'MEDIUM').toUpperCase();
    var employeeId =
        visit?['employee_id'] as String? ??
        (_employees.isNotEmpty ? _employees.first['id'] as String? : null);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(visit == null ? 'CREATE VISIT' : 'EDIT VISIT'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: client,
                decoration: const InputDecoration(labelText: 'Client'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: objective,
                decoration: const InputDecoration(labelText: 'Objective'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (value) => priority = value ?? 'MEDIUM',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: employeeId,
                decoration: const InputDecoration(labelText: 'Assign employee'),
                items: _employees
                    .map(
                      (employee) => DropdownMenuItem(
                        value: employee['id'] as String,
                        child: Text(_employeeDropdownLabel(employee)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => employeeId = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                'client_name': client.text.trim(),
                'site_name': client.text.trim(),
                'site_address': address.text.trim(),
                'employee_id': employeeId,
                'objective': objective.text.trim(),
                'priority': priority,
                'scheduled_at': DateTime.now()
                    .add(const Duration(days: 1))
                    .toIso8601String(),
              };
              try {
                payload['organization_id'] = await supabase.rpc(
                  'current_profile_org_id',
                );
              } catch (_) {}
              try {
                if (visit == null) {
                  await supabase.from('visits').insert(payload);
                } else {
                  await supabase
                      .from('visits')
                      .update(payload)
                      .eq('id', visit['id'] as String);
                }
                await _load();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$error')));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelVisit(Map<String, dynamic> visit) async {
    try {
      await supabase
          .from('visits')
          .update({'status': 'CANCELLED'})
          .eq('id', visit['id'] as String);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _VisitMapPanel extends StatelessWidget {
  const _VisitMapPanel({
    required this.visits,
    required this.employees,
    required this.loading,
  });

  final List<Map<String, dynamic>> visits;
  final List<Map<String, dynamic>> employees;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final pinnedVisits = visits.where(_hasCoordinates).toList(growable: false);
    final center = _mapCenter(pinnedVisits);
    final zoom = _mapZoom(pinnedVisits);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Visit Map'.toUpperCase(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${pinnedVisits.length} pinned visits',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 380,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: zoom,
                        minZoom: 3,
                        maxZoom: 19,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.dooninfra.admin.visit_map',
                        ),
                        MarkerLayer(
                          markers: pinnedVisits
                              .map(
                                (visit) => Marker(
                                  point: LatLng(_lat(visit)!, _lng(visit)!),
                                  width: 62,
                                  height: 70,
                                  child: Tooltip(
                                    message:
                                        '${_clientName(visit)}\n${_employeeName(visit, employees)}\n${_visitLocation(visit)}',
                                    child: GestureDetector(
                                      onTap: () => _showVisitMapDetails(
                                        context,
                                        visit,
                                        employees,
                                      ),
                                      child: const _VisitPinMarker(),
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (loading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(),
                      ),
                    if (pinnedVisits.isEmpty)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.48),
                        child: const Center(
                          child: Text(
                            'No marked visit locations are available yet.',
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFFF9C74F),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'VISIT LOCATION',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVisitMapDetails(
    BuildContext context,
    Map<String, dynamic> visit,
    List<Map<String, dynamic>> employees,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_clientName(visit)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VisitMapLine('Employee', _employeeName(visit, employees)),
            _VisitMapLine('Visit Time', _visitTime(visit)),
            _VisitMapLine('Status', _status(visit)),
            _VisitMapLine('Location', _visitLocation(visit)),
            _VisitMapLine(
              'GPS',
              '${_lat(visit)!.toStringAsFixed(6)}, ${_lng(visit)!.toStringAsFixed(6)}',
            ),
            _VisitMapLine('Photos', '${_photos(visit).length}'),
            if ((visit['notes']?.toString().trim().isNotEmpty ?? false))
              _VisitMapLine('Notes', visit['notes'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class _VisitPinMarker extends StatelessWidget {
  const _VisitPinMarker();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.assignment_turned_in, color: Color(0xFFF9C74F), size: 28),
        Icon(Icons.location_on, color: Color(0xFFF9C74F), size: 42),
      ],
    );
  }
}

class _VisitMapLine extends StatelessWidget {
  const _VisitMapLine(this.label, this.value);

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
            width: 104,
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

class _VisitTable extends StatelessWidget {
  const _VisitTable({
    required this.visits,
    required this.employees,
    required this.loading,
    required this.onEdit,
    required this.onCancel,
    required this.onViewPhotos,
  });

  final List<Map<String, dynamic>> visits;
  final List<Map<String, dynamic>> employees;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onCancel;
  final ValueChanged<Map<String, dynamic>> onViewPhotos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Visit Monitoring'.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Outcome')),
                  DataColumn(label: Text('Photos')),
                  DataColumn(label: Text('Score')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: visits
                    .map(
                      (visit) => DataRow(
                        cells: [
                          DataCell(Text(_clientName(visit))),
                          DataCell(Text(_employeeName(visit, employees))),
                          DataCell(
                            Text(
                              _label(visit['priority'] as String? ?? 'MEDIUM'),
                            ),
                          ),
                          DataCell(Text(_status(visit))),
                          DataCell(Text(visit['outcome'] as String? ?? '--')),
                          DataCell(Text('${_photos(visit).length}')),
                          DataCell(Text('${visit['productivity_score'] ?? 0}')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'View proof photos',
                                  onPressed: () => onViewPhotos(visit),
                                  icon: Badge.count(
                                    count: _photos(visit).length,
                                    isLabelVisible: _photos(visit).isNotEmpty,
                                    child: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => onEdit(visit),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: () => onCancel(visit),
                                  icon: const Icon(Icons.cancel_outlined),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.stats, required this.visits});

  final _VisitStats stats;
  final List<Map<String, dynamic>> visits;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit Details Dashboard'.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _Line('Photos', '${_countNested('visit_photos')}'),
            _Line('Notes', '${_countNested('visit_notes')}'),
            _Line('Voice Notes', '${_countNested('visit_audio_notes')}'),
            _Line('Documents', '${_countNested('visit_documents')}'),
            _Line('Signatures', '${_countNested('visit_signatures')}'),
            _Line('Follow-up Rate', '${stats.followUpRate}%'),
            _Line('Average Duration', '${stats.averageDurationMinutes}m'),
          ],
        ),
      ),
    );
  }

  int _countNested(String key) {
    return visits.fold(
      0,
      (sum, visit) => sum + ((visit[key] as List<dynamic>?)?.length ?? 0),
    );
  }
}

class _VisitEvidencePanel extends StatelessWidget {
  const _VisitEvidencePanel({required this.visits});

  final List<Map<String, dynamic>> visits;

  @override
  Widget build(BuildContext context) {
    final visitsWithPhotos = visits
        .where((visit) => _photos(visit).isNotEmpty)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit Proof Photos'.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (visitsWithPhotos.isEmpty)
              const Text('No visit proof photos have been uploaded yet.'),
            ...visitsWithPhotos.take(6).map((visit) {
              final photo = _photos(visit).first;
              final url = _photoUrl(photo);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: url == null
                    ? const Icon(Icons.no_photography_outlined)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          url,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                title: Text(_clientName(visit)),
                subtitle: Text(
                  photo['readable_location'] as String? ??
                      '${_lat(visit)?.toStringAsFixed(5) ?? '--'}, ${_lng(visit)?.toStringAsFixed(5) ?? '--'}',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});

  final Map<String, dynamic> photo;

  @override
  Widget build(BuildContext context) {
    final url = _photoUrl(photo);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: url == null
                  ? const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.no_photography_outlined, size: 42),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.broken_image_outlined, size: 42),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(photo['category']?.toString() ?? 'Visit Photo'),
                const SizedBox(height: 4),
                Text(
                  photo['readable_location']?.toString() ??
                      'Location not recorded',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (photo['storage_path'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    photo['storage_path'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeePerformance extends StatelessWidget {
  const _EmployeePerformance({required this.visits, required this.employees});

  final List<Map<String, dynamic>> visits;
  final List<Map<String, dynamic>> employees;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final visit in visits) {
      grouped
          .putIfAbsent(
            visit['employee_id']?.toString() ?? 'Unassigned',
            () => [],
          )
          .add(visit);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee Visit Performance'.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...grouped.entries.map((entry) {
              final stats = _VisitStats(entry.value);
              final visit = entry.value.first;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_employeeName(visit, employees)),
                subtitle: Text(
                  'Completed ${stats.completed} • Conversion ${stats.conversionRate}% • Follow-ups ${stats.followUps}',
                ),
                trailing: Text('${stats.productivityScore}'),
              );
            }),
          ],
        ),
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineLarge),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}

class _VisitStats {
  _VisitStats(this.visits);

  final List<Map<String, dynamic>> visits;

  int get total => visits.length;
  int get pending => visits.where((v) => _status(v) == 'Pending').length;
  int get active => visits.where((v) => _status(v) == 'In Progress').length;
  int get completed => visits.where((v) => _status(v) == 'Completed').length;
  int get missed => visits.where((v) => _status(v) == 'Missed').length;
  int get followUps => visits.fold(
    0,
    (sum, v) => sum + ((v['visit_followups'] as List<dynamic>?)?.length ?? 0),
  );
  int get conversionRate =>
      total == 0 ? 0 : ((completed / total) * 100).round();
  int get followUpRate => total == 0 ? 0 : ((followUps / total) * 100).round();
  int get averageDurationMinutes {
    final durations = visits
        .map((v) {
          final started = DateTime.tryParse(v['started_at'] as String? ?? '');
          final ended = DateTime.tryParse(v['ended_at'] as String? ?? '');
          if (started == null || ended == null) return 0;
          return ended.difference(started).inMinutes;
        })
        .where((v) => v > 0)
        .toList();
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) ~/ durations.length;
  }

  int get productivityScore {
    if (visits.isEmpty) return 0;
    final totalScore = visits.fold<int>(
      0,
      (sum, v) => sum + ((v['productivity_score'] as num?)?.toInt() ?? 0),
    );
    return totalScore ~/ visits.length;
  }
}

String _clientName(Map<String, dynamic> visit) {
  final client = visit['clients'] as Map<String, dynamic>?;
  return client?['company_name'] as String? ??
      visit['client_name'] as String? ??
      'Client';
}

String _employeeName(
  Map<String, dynamic> visit,
  List<Map<String, dynamic>> employees,
) {
  final employeeId = visit['employee_id']?.toString();
  if (employeeId == null || employeeId.isEmpty) return 'Unassigned';
  final employee = employees.cast<Map<String, dynamic>?>().firstWhere(
    (row) =>
        row?['id']?.toString() == employeeId ||
        row?['auth_user_id']?.toString() == employeeId ||
        row?['employee_id']?.toString() == employeeId,
    orElse: () => null,
  );
  final meta = Map<String, dynamic>.from(employee?['meta'] as Map? ?? {});
  final fullName =
      employee?['full_name']?.toString().trim() ??
      meta['fullName']?.toString().trim() ??
      meta['name']?.toString().trim();
  final email = employee?['email']?.toString().trim();
  final code = employee?['employee_id']?.toString().trim();
  return fullName?.isNotEmpty == true
      ? fullName!
      : email?.isNotEmpty == true
      ? email!
      : code?.isNotEmpty == true
      ? code!
      : _shortId(employeeId);
}

String _status(Map<String, dynamic> visit) {
  final raw = (visit['status'] as String? ?? 'ASSIGNED').toUpperCase();
  if (raw == 'STARTED' || raw == 'IN_PROGRESS') return 'In Progress';
  if (raw == 'COMPLETED' || raw == 'VERIFIED') return 'Completed';
  if (raw == 'MISSED') return 'Missed';
  if (raw == 'CANCELLED') return 'Cancelled';
  if (raw == 'RESCHEDULED') return 'Rescheduled';
  return 'Pending';
}

String _label(String value) {
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _shortId(String? id) {
  if (id == null || id.isEmpty) return '--';
  return id.length <= 8 ? id : id.substring(0, 8);
}

List<Map<String, dynamic>> _photos(Map<String, dynamic> visit) {
  final photos = (visit['visit_photos'] as List<dynamic>? ?? const [])
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
  final imageUrl = visit['image_url']?.toString();
  if (photos.isEmpty && imageUrl != null && imageUrl.isNotEmpty) {
    return [
      {
        'category': 'Visit Photo',
        'public_url': imageUrl,
        'readable_location':
            '${_lat(visit)?.toStringAsFixed(5) ?? '--'}, ${_lng(visit)?.toStringAsFixed(5) ?? '--'}',
      },
    ];
  }
  return photos;
}

String? _photoUrl(Map<String, dynamic> photo) {
  final value =
      photo['display_url']?.toString() ??
      photo['public_url']?.toString() ??
      photo['storage_path']?.toString();
  if (value == null || value.isEmpty || !value.startsWith('http')) {
    return null;
  }
  return value;
}

bool _hasCoordinates(Map<String, dynamic> visit) {
  return _lat(visit) != null && _lng(visit) != null;
}

LatLng _mapCenter(List<Map<String, dynamic>> visits) {
  if (visits.isEmpty) return const LatLng(28.6139, 77.2090);
  final latitude =
      visits.map((visit) => _lat(visit)!).reduce((a, b) => a + b) /
      visits.length;
  final longitude =
      visits.map((visit) => _lng(visit)!).reduce((a, b) => a + b) /
      visits.length;
  return LatLng(latitude, longitude);
}

double _mapZoom(List<Map<String, dynamic>> visits) {
  if (visits.length <= 1) return 14;
  final latitudes = visits.map((visit) => _lat(visit)!).toList();
  final longitudes = visits.map((visit) => _lng(visit)!).toList();
  final latSpan =
      latitudes.reduce((a, b) => a > b ? a : b) -
      latitudes.reduce((a, b) => a < b ? a : b);
  final lngSpan =
      longitudes.reduce((a, b) => a > b ? a : b) -
      longitudes.reduce((a, b) => a < b ? a : b);
  final span = latSpan > lngSpan ? latSpan : lngSpan;
  if (span > 10) return 5;
  if (span > 3) return 7;
  if (span > 1) return 9;
  if (span > 0.2) return 11;
  return 13;
}

String _visitTime(Map<String, dynamic> visit) {
  final raw =
      visit['ended_at']?.toString() ??
      visit['started_at']?.toString() ??
      visit['created_at']?.toString() ??
      visit['scheduled_at']?.toString();
  final parsed = DateTime.tryParse(raw ?? '');
  if (parsed == null) return '--';
  final local = parsed.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _visitLocation(Map<String, dynamic> visit) {
  final siteAddress = visit['site_address']?.toString().trim();
  if (siteAddress != null && siteAddress.isNotEmpty) return siteAddress;
  final clientAddress = ((visit['clients'] as Map?)?['address'] as String?)
      ?.trim();
  if (clientAddress != null && clientAddress.isNotEmpty) return clientAddress;
  return '${_lat(visit)?.toStringAsFixed(5) ?? '--'}, ${_lng(visit)?.toStringAsFixed(5) ?? '--'}';
}

double? _lat(Map<String, dynamic> visit) {
  final photos = visit['visit_photos'] as List<dynamic>? ?? const [];
  double? photoLat;
  if (photos.isNotEmpty) {
    final first = Map<String, dynamic>.from(photos.first as Map);
    photoLat = (first['latitude'] as num?)?.toDouble();
  }
  return (visit['end_lat'] as num?)?.toDouble() ??
      (visit['start_lat'] as num?)?.toDouble() ??
      photoLat ??
      (visit['client_lat'] as num?)?.toDouble() ??
      ((visit['clients'] as Map?)?['latitude'] as num?)?.toDouble();
}

double? _lng(Map<String, dynamic> visit) {
  final photos = visit['visit_photos'] as List<dynamic>? ?? const [];
  double? photoLng;
  if (photos.isNotEmpty) {
    final first = Map<String, dynamic>.from(photos.first as Map);
    photoLng = (first['longitude'] as num?)?.toDouble();
  }
  return (visit['end_lng'] as num?)?.toDouble() ??
      (visit['start_lng'] as num?)?.toDouble() ??
      photoLng ??
      (visit['client_lng'] as num?)?.toDouble() ??
      ((visit['clients'] as Map?)?['longitude'] as num?)?.toDouble();
}

String _employeeDropdownLabel(Map<String, dynamic> employee) {
  final name = employee['full_name']?.toString().trim().isNotEmpty == true
      ? employee['full_name'].toString()
      : employee['email']?.toString() ?? 'Employee';
  final code = employee['employee_id']?.toString().trim();
  if (code == null || code.isEmpty) return '$name (Employee ID pending)';
  return '$name ($code)';
}
