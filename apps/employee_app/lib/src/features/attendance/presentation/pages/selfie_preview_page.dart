import 'dart:io';
import 'package:flutter/material.dart';

class SelfiePreviewPage extends StatelessWidget {
  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  const SelfiePreviewPage({
    super.key,
    required this.imageFile,
    required this.onConfirm,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('REVIEW SELFIE'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Preview image
          Expanded(
            child: Container(
              color: Colors.black87,
              child: Center(child: Image.file(imageFile, fit: BoxFit.cover)),
            ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outline, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Info message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ensure your face is clearly visible and well-lit',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    child: const Text('CONFIRM & SUBMIT'),
                  ),
                ),
                const SizedBox(height: 12),

                // Retake button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onRetake,
                    child: const Text('RETAKE PHOTO'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
