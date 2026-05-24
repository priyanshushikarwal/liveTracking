import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/live_employee.dart';
import '../viewmodels/live_tracking_view_model.dart';

class LiveTrackingMap extends StatefulWidget {
  const LiveTrackingMap({
    required this.employees,
    required this.routeVisitPins,
    required this.selectedEmployee,
    required this.routeTrails,
    required this.playback,
    required this.playbackCursor,
    required this.stopMarkers,
    required this.employeeColor,
    required this.selectedRouteColor,
    required this.onEmployeeTap,
    super.key,
  });

  final List<LiveEmployee> employees;
  final List<VisitMapPin> routeVisitPins;
  final LiveEmployee? selectedEmployee;
  final Map<String, List<PlaybackPoint>> routeTrails;
  final List<PlaybackPoint> playback;
  final PlaybackPoint? playbackCursor;
  final List<PlaybackPoint> stopMarkers;
  final Color Function(LiveEmployee employee) employeeColor;
  final Color selectedRouteColor;
  final ValueChanged<String> onEmployeeTap;

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _routeAnimationController;
  late final Animation<double> _routeAnimation;
  double _zoom = 14.0;
  List<PlaybackPoint> _previousPlayback = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _routeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _routeAnimation = CurvedAnimation(
      parent: _routeAnimationController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.playback.isNotEmpty) {
      _routeAnimationController.value = 1.0;
      _previousPlayback = widget.playback;
    }
  }

  @override
  void didUpdateWidget(LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playback != oldWidget.playback && widget.playback.isNotEmpty) {
      if (_previousPlayback.isEmpty ||
          widget.playback.length != _previousPlayback.length) {
        _routeAnimationController.forward(from: 0.0);
      }
      _previousPlayback = widget.playback;
    } else if (widget.playback.isEmpty) {
      _routeAnimationController.value = 0.0;
      _previousPlayback = [];
    }
  }

  @override
  void dispose() {
    _routeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerEmployees = widget.employees
        .where((employee) => employee.latitude != 0 || employee.longitude != 0)
        .toList(growable: false);
    final markers = _clusterMarkers(markerEmployees, _zoom);
    final selectedTrail = widget.selectedEmployee == null
        ? const <PlaybackPoint>[]
        : widget.routeTrails[widget.selectedEmployee!.id] ??
              const <PlaybackPoint>[];
    final playbackPoints = widget.playback
        .map((item) => item.latLng)
        .toList(growable: false);
    final routePoints = selectedTrail
        .map((item) => item.latLng)
        .toList(growable: false);
    final routeColor = widget.selectedRouteColor;
    final focus =
        widget.playbackCursor?.latLng ??
        (widget.selectedEmployee == null ||
                (widget.selectedEmployee!.latitude == 0 &&
                    widget.selectedEmployee!.longitude == 0)
            ? null
            : LatLng(
                widget.selectedEmployee!.latitude,
                widget.selectedEmployee!.longitude,
              ));
    debugPrint(
      '[TrackingDebug] map render markers=${markers.length} routePoints=${routePoints.length} playbackPoints=${playbackPoints.length} routeVisitPins=${widget.routeVisitPins.length}',
    );

    if (focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(focus, math.max(_zoom, 12));
        }
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(25.62452, 74.93352),
              initialZoom: _zoom,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (position, _) {
                _zoom = position.zoom ?? _zoom;
                setState(() {});
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dooninfra.live_tracking.admin',
              ),
              if (routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4,
                      color: routeColor.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              if (playbackPoints.length > 1)
                AnimatedBuilder(
                  animation: _routeAnimation,
                  builder: (context, child) {
                    final pointsCount =
                        (playbackPoints.length * _routeAnimation.value).ceil();
                    final visiblePoints = playbackPoints
                        .take(pointsCount)
                        .toList();
                    if (visiblePoints.length < 2) {
                      return const SizedBox.shrink();
                    }

                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: visiblePoints,
                          strokeWidth: 5,
                          color: routeColor,
                        ),
                      ],
                    );
                  },
                ),
              // Removed static playback line since it's animated above
              if (widget.stopMarkers.isNotEmpty)
                MarkerLayer(
                  markers: widget.stopMarkers
                      .map(
                        (stop) => Marker(
                          point: stop.latLng,
                          width: 52,
                          height: 52,
                          child: Icon(
                            Icons.pause_circle_filled,
                            color: const Color(0xFFF9C74F),
                            size: 34,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (widget.routeVisitPins.isNotEmpty)
                MarkerLayer(
                  markers: widget.routeVisitPins
                      .map(
                        (pin) => Marker(
                          point: pin.latLng,
                          width: 190,
                          height: 112,
                          child: _VisitMapMarker(pin: pin),
                        ),
                      )
                      .toList(growable: false),
                ),
              MarkerLayer(
                markers: [
                  ...markers,
                  if (widget.playbackCursor != null)
                    Marker(
                      point: widget.playbackCursor!.latLng,
                      width: 86,
                      height: 86,
                      child: _PlaybackMarker(color: routeColor),
                    ),
                ],
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
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.add,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _zoom + 1,
                  ),
                ),
                const SizedBox(height: 10),
                _MapButton(
                  icon: Icons.remove,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _zoom - 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _clusterMarkers(List<LiveEmployee> employees, double zoom) {
    final buckets = <String, List<LiveEmployee>>{};
    final cell = math.max(0.02, 30 / math.pow(2, zoom).toDouble());

    for (final employee in employees) {
      final key =
          '${(employee.latitude / cell).floor()}:${(employee.longitude / cell).floor()}';
      buckets.putIfAbsent(key, () => <LiveEmployee>[]).add(employee);
    }

    return buckets.values
        .map((group) {
          if (group.length == 1) {
            final employee = group.first;
            return Marker(
              point: LatLng(employee.latitude, employee.longitude),
              width: 120,
              height: 84,
              child: GestureDetector(
                onTap: () => widget.onEmployeeTap(employee.id),
                child: _EmployeeMapMarker(
                  name: employee.name,
                  code: employee.employeeCode,
                  color: widget.employeeColor(employee),
                  selected: widget.selectedEmployee?.id == employee.id,
                  bearing: employee.bearing,
                  online: employee.isOnline,
                ),
              ),
            );
          }

          final latitude =
              group.map((item) => item.latitude).reduce((a, b) => a + b) /
              group.length;
          final longitude =
              group.map((item) => item.longitude).reduce((a, b) => a + b) /
              group.length;
          return Marker(
            point: LatLng(latitude, longitude),
            width: 78,
            height: 78,
            child: GestureDetector(
              onTap: () =>
                  _mapController.move(LatLng(latitude, longitude), _zoom + 1.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${group.length}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }
}

class _EmployeeMapMarker extends StatelessWidget {
  const _EmployeeMapMarker({
    required this.name,
    required this.code,
    required this.color,
    required this.selected,
    required this.bearing,
    required this.online,
  });

  final String name;
  final String code;
  final Color color;
  final bool selected;
  final double bearing;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: selected ? 1.0 : 0.94, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? color : Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: Column(
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  code,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: online ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitMapMarker extends StatelessWidget {
  const _VisitMapMarker({required this.pin});

  final VisitMapPin pin;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${pin.clientName}\n${pin.employeeName}\n${pin.notes.isEmpty ? 'Visit submitted' : pin.notes}',
      child: GestureDetector(
        onTap: () => _showVisitPopup(context, pin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 172),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.assignment_turned_in,
                        color: Color(0xFFF9C74F),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pin.clientName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    pin.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.location_pin, color: Color(0xFFF9C74F), size: 38),
          ],
        ),
      ),
    );
  }

  void _showVisitPopup(BuildContext context, VisitMapPin pin) {
    debugPrint('[TrackingDebug] visit pin rendered/opened ${pin.id}');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pin.clientName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VisitPopupLine('Employee', pin.employeeName),
            _VisitPopupLine('Visit Time', pin.submittedAt.toLocal().toString()),
            _VisitPopupLine(
              'Location',
              pin.locationLabel ??
                  '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}',
            ),
            _VisitPopupLine('Visit Status', pin.status),
            _VisitPopupLine('Photos Uploaded', '${pin.photoCount}'),
            _VisitPopupLine('Notes Count', '${pin.notesCount}'),
            if (pin.notes.isNotEmpty) _VisitPopupLine('Notes', pin.notes),
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

class _VisitPopupLine extends StatelessWidget {
  const _VisitPopupLine(this.label, this.value);

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
            width: 118,
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

class _PlaybackMarker extends StatelessWidget {
  const _PlaybackMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 4),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
