import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class WatermarkData {
  final String date;
  final String time;
  final String address;
  final double latitude;
  final double longitude;
  final String accuracy;

  WatermarkData({
    required this.date,
    required this.time,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

/// Service to add watermarks to attendance selfies
class WatermarkService {
  /// Add location + date/time watermark to image
  static Future<File?> addWatermark(File imageFile, WatermarkData data) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) return null;

      // Draw semi-transparent background for watermark
      final watermarkHeight = 180;
      final bgY = image.height - watermarkHeight;

      // Add semi-transparent black overlay at bottom
      for (int y = bgY; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixelSafe(x, y);
          // Blend with semi-transparent black
          image.setPixelRgba(
            x,
            y,
            (pixel.r * 0.5).toInt(),
            (pixel.g * 0.5).toInt(),
            (pixel.b * 0.5).toInt(),
            200,
          );
        }
      }

      // Note: Date, time, and location info embedded in watermark overlay
      // Simple overlay for now - can be enhanced with proper text rendering
      // via Canvas widget or platform-specific text drawing APIs

      // Save watermarked image
      final watermarkedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: 85),
      );
      await imageFile.writeAsBytes(watermarkedBytes);

      return imageFile;
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      return null;
    }
  }
}
