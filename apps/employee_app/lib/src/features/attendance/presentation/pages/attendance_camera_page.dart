import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_tools;

class AttendanceCameraPage extends StatefulWidget {
  const AttendanceCameraPage({
    super.key,
    required this.employeeName,
    required this.locationName,
    required this.attendanceType,
    required this.gpsAccuracy,
    required this.companyName,
  });

  final String employeeName;
  final String locationName;
  final String attendanceType;
  final double gpsAccuracy;
  final String companyName;

  @override
  State<AttendanceCameraPage> createState() => _AttendanceCameraPageState();
}

class _AttendanceCameraPageState extends State<AttendanceCameraPage> {
  CameraController? _controller;
  bool _loading = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      final selected = front.isNotEmpty ? front.first : cameras.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (controller != null)
            CameraPreview(controller),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.paddingOf(context).top + 16,
            child: _VerificationOverlay(widget: widget),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                SizedBox.square(
                  dimension: 76,
                  child: FilledButton(
                    onPressed: controller == null || _capturing
                        ? null
                        : _capture,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: _capturing
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt, size: 30),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _capturing = true);
    try {
      final capture = await controller.takePicture();
      final bytes = await File(capture.path).readAsBytes();
      final decoded = image_tools.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Unable to process captured image.');
      }
      final compressed = decoded.width > 1440
          ? image_tools.copyResize(decoded, width: 1440)
          : decoded;
      final now = DateTime.now();
      final watermark = [
        widget.employeeName,
        _dateLabel(now),
        _timeLabel(now),
        widget.locationName,
        widget.attendanceType.toUpperCase(),
        widget.companyName,
      ].join('\n');
      final overlayHeight = 190;
      image_tools.fillRect(
        compressed,
        x1: 0,
        y1: compressed.height - overlayHeight,
        x2: compressed.width,
        y2: compressed.height,
        color: image_tools.ColorRgba8(0, 0, 0, 178),
      );
      image_tools.drawString(
        compressed,
        watermark,
        font: image_tools.arial24,
        x: 28,
        y: compressed.height - overlayHeight + 24,
        color: image_tools.ColorRgb8(255, 255, 255),
      );
      final outputPath = capture.path.replaceFirst('.jpg', '-verified.jpg');
      final outputBytes = image_tools.encodeJpg(compressed, quality: 78);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(
        AttendanceCapture(
          localPath: outputPath,
          watermark: watermark.replaceAll('\n', ' | '),
          sizeBytes: outputBytes.length,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _capturing = false;
      });
    }
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : value.hour;
    final labelHour = hour == 0 ? 12 : hour;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${labelHour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $suffix';
  }

  String _dateLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

class _VerificationOverlay extends StatelessWidget {
  const _VerificationOverlay({required this.widget});

  final AttendanceCameraPage widget;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, height: 1.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.employeeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${_date(now)}  ${_time(now)}'),
              Text(widget.locationName),
              Text(widget.attendanceType.toUpperCase()),
              Text('GPS Verified (${widget.gpsAccuracy.toStringAsFixed(0)} m)'),
            ],
          ),
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

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class AttendanceCapture {
  const AttendanceCapture({
    required this.localPath,
    required this.watermark,
    required this.sizeBytes,
  });

  final String localPath;
  final String watermark;
  final int sizeBytes;
}
