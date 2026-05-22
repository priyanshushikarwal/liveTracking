import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../core/widgets/app_shell.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  String? captureSummary;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Camera',
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IN-APP CAMERA ONLY'),
                  const SizedBox(height: 12),
                  const Text(
                    'Gallery upload is disabled. Photos are captured inside the app, watermarked, compressed, and prepared for secure upload.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final media = await ref
                          .read(cameraServiceProvider)
                          .captureWatermarkedImage(
                            employeeName: 'Employee',
                            clientName: 'Metro Retail LLP',
                            latitude: 28.4595,
                            longitude: 77.0266,
                          );
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        captureSummary =
                            'Captured ${media.localPath}\nWatermark: ${media.watermark}\nEstimated size: ${media.compressedBytesEstimate} bytes';
                      });
                    },
                    child: const Text('CAPTURE WATERMARKED PHOTO'),
                  ),
                  if (captureSummary != null) ...[
                    const SizedBox(height: 16),
                    Text(captureSummary!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
