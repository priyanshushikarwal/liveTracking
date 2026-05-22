import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image_tools;

final cameraServiceProvider = Provider<CameraService>((ref) {
  return const CameraService();
});

class CameraService {
  const CameraService();

  Future<CapturedMedia> captureWatermarkedImage({
    required String employeeName,
    required String clientName,
    required double latitude,
    required double longitude,
    BuildContext? context,
  }) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const CameraServiceException(
        'No camera is available on this device.',
      );
    }

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (context != null && !context.mounted) {
        throw const CameraServiceException('Camera screen is not available.');
      }
      final capture = context == null
          ? await controller.takePicture()
          // ignore: use_build_context_synchronously
          : await _showCameraPreview(context, controller);
      final bytes = await File(capture.path).readAsBytes();
      final decoded = image_tools.decodeImage(bytes);
      if (decoded == null) {
        throw const CameraServiceException('Unable to process captured image.');
      }

      final compressed = decoded.width > 1440
          ? image_tools.copyResize(decoded, width: 1440)
          : decoded;
      final timestamp = DateTime.now().toLocal().toString().substring(0, 19);
      final watermark =
          '$employeeName | $clientName\n$timestamp | ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

      image_tools.fillRect(
        compressed,
        x1: 0,
        y1: compressed.height - 96,
        x2: compressed.width,
        y2: compressed.height,
        color: image_tools.ColorRgba8(0, 0, 0, 170),
      );
      image_tools.drawString(
        compressed,
        watermark,
        font: image_tools.arial24,
        x: 24,
        y: compressed.height - 76,
        color: image_tools.ColorRgb8(255, 255, 255),
      );

      final outputPath = capture.path.replaceFirst('.jpg', '-watermarked.jpg');
      final outputBytes = image_tools.encodeJpg(compressed, quality: 78);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);

      return CapturedMedia(
        localPath: outputPath,
        watermark: watermark.replaceAll('\n', ' | '),
        compressedBytesEstimate: outputBytes.length,
      );
    } finally {
      await controller.dispose();
    }
  }

  Future<XFile> _showCameraPreview(
    BuildContext context,
    CameraController controller,
  ) async {
    if (!context.mounted) {
      throw const CameraServiceException('Camera screen is not available.');
    }

    final capture = await showDialog<XFile>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var capturing = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog.fullscreen(
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: CameraPreview(controller)),
                    Positioned(
                      top: 18,
                      left: 12,
                      child: SafeArea(
                        child: IconButton.filledTonal(
                          onPressed: capturing
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 28,
                      child: SafeArea(
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: capturing
                                ? null
                                : () async {
                                    setState(() => capturing = true);
                                    try {
                                      final file = await controller
                                          .takePicture();
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop(file);
                                      }
                                    } catch (_) {
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    }
                                  },
                            icon: capturing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: Text(capturing ? 'Capturing' : 'Capture'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (capture == null) {
      throw const CameraServiceException('Photo capture was cancelled.');
    }
    return capture;
  }
}

class CapturedMedia {
  const CapturedMedia({
    required this.localPath,
    required this.watermark,
    required this.compressedBytesEstimate,
  });

  final String localPath;
  final String watermark;
  final int compressedBytesEstimate;
}

class CameraServiceException implements Exception {
  const CameraServiceException(this.message);

  final String message;
}
