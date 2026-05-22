import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraCaptureArg {
  final List<CameraDescription> cameras;

  CameraCaptureArg({required this.cameras});
}

class CameraCapturePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraCapturePage({super.key, required this.cameras});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Find front camera
      final frontCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isInitialized || _isTakingPhoto) return;

    setState(() => _isTakingPhoto = true);

    try {
      final photo = await _controller.takePicture();
      final file = File(photo.path);

      if (mounted) {
        // Return the captured image file to previous screen
        Navigator.pop(context, file);
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
        setState(() => _isTakingPhoto = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('CAPTURE SELFIE'),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: Colors.black,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CAPTURE SELFIE'),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_controller),

          // Guide overlay
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text(
                'Position your face clearly in the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Face guide circle
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isTakingPhoto ? null : _capturePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isTakingPhoto
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isTakingPhoto ? 'CAPTURING...' : 'TAP TO CAPTURE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Watermark info
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your selfie will be watermarked with date, time, and location',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
