import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackingMap extends StatefulWidget {
  const TrackingMap({
    required this.routePoints,
    required this.serverRoutePoints,
    required this.currentPoint,
    required this.accuracyMeters,
    required this.followEmployee,
    required this.onToggleFollow,
    super.key,
  });

  final List<LatLng> routePoints;
  final List<LatLng> serverRoutePoints;
  final LatLng? currentPoint;
  final double accuracyMeters;
  final bool followEmployee;
  final VoidCallback onToggleFollow;

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _markerController;
  Animation<LatLng>? _markerAnimation;
  LatLng? _animatedPoint;
  double _zoom = 15;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animatedPoint = widget.currentPoint;
    _markerController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addListener(() {
          final next = _markerAnimation?.value;
          if (next != null) {
            setState(() => _animatedPoint = next);
          }
        });
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPoint = widget.currentPoint;
    final previousPoint = oldWidget.currentPoint;
    if (nextPoint != null &&
        previousPoint != null &&
        nextPoint != previousPoint) {
      _markerAnimation =
          LatLngTween(
            begin: _animatedPoint ?? previousPoint,
            end: nextPoint,
          ).animate(
            CurvedAnimation(
              parent: _markerController,
              curve: Curves.easeOutCubic,
            ),
          );
      _markerController
        ..reset()
        ..forward();
    } else if (nextPoint != null && previousPoint == null) {
      _animatedPoint = nextPoint;
    }

    if (widget.followEmployee && nextPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(nextPoint, _zoom);
        }
      });
    }
  }

  @override
  void dispose() {
    _markerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = widget.currentPoint ?? const LatLng(28.4595, 77.0266);
    final currentPoint = _animatedPoint ?? widget.currentPoint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _zoom,
              maxZoom: 19,
              minZoom: 4,
              onPositionChanged: (position, _) {
                _zoom = position.zoom ?? _zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dooninfra.live_tracking.employee',
              ),
              if (widget.serverRoutePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.serverRoutePoints,
                      strokeWidth: 6,
                      color: theme.colorScheme.primary.withValues(alpha: 0.46),
                    ),
                  ],
                ),
              if (widget.routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints,
                      strokeWidth: 4,
                      color: theme.colorScheme.primary.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              if (currentPoint != null && widget.accuracyMeters > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: currentPoint,
                      radius: widget.accuracyMeters.clamp(8, 120),
                      useRadiusInMeter: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderColor: theme.colorScheme.primary.withValues(
                        alpha: 0.38,
                      ),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (currentPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPoint,
                      width: 92,
                      height: 92,
                      child: _PulseMarker(color: theme.colorScheme.primary),
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
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: Text(
                currentPoint == null
                    ? 'Waiting for first GPS fix'
                    : 'OpenStreetMap live view',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _MapActionButton(
                  icon: Icons.add,
                  onTap: () => _mapController.move(center, _zoom + 1),
                ),
                const SizedBox(height: 10),
                _MapActionButton(
                  icon: Icons.remove,
                  onTap: () => _mapController.move(center, _zoom - 1),
                ),
                const SizedBox(height: 10),
                _MapActionButton(
                  icon: widget.followEmployee
                      ? Icons.gps_fixed
                      : Icons.gps_not_fixed,
                  onTap: widget.onToggleFollow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _PulseMarker extends StatelessWidget {
  const _PulseMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.85, end: 1.1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      onEnd: () {},
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}
