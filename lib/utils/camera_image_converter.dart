import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Serializable camera frame for background isolate processing.
class LiveCameraFrame {
  LiveCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planeBytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  factory LiveCameraFrame.fromCameraImage(CameraImage image) {
    return LiveCameraFrame(
      width: image.width,
      height: image.height,
      format: image.format.group,
      planeBytes: image.planes.map((plane) => Uint8List.fromList(plane.bytes)).toList(),
      bytesPerRow: image.planes.map((plane) => plane.bytesPerRow).toList(),
      bytesPerPixel: image.planes.map((plane) => plane.bytesPerPixel).toList(),
    );
  }

  final int width;
  final int height;
  final ImageFormatGroup format;
  final List<Uint8List> planeBytes;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;
}

class CameraImageConverter {
  static img.Image? toImage(LiveCameraFrame frame) {
    switch (frame.format) {
      case ImageFormatGroup.bgra8888:
        return _fromBgra8888(frame);
      case ImageFormatGroup.yuv420:
      case ImageFormatGroup.nv21:
        return _fromYuv420(frame);
      default:
        return null;
    }
  }

  static img.Image? _fromBgra8888(LiveCameraFrame frame) {
    if (frame.planeBytes.isEmpty) return null;

    return img.Image.fromBytes(
      width: frame.width,
      height: frame.height,
      bytes: frame.planeBytes.first.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image? _fromYuv420(LiveCameraFrame frame) {
    if (frame.planeBytes.length < 2) return null;

    final yPlane = frame.planeBytes[0];
    final yRowStride = frame.bytesPerRow[0];

    final image = img.Image(width: frame.width, height: frame.height);

    if (frame.planeBytes.length >= 3) {
      final uPlane = frame.planeBytes[1];
      final vPlane = frame.planeBytes[2];
      final uvRowStride = frame.bytesPerRow[1];
      final uvPixelStride = frame.bytesPerPixel[1] ?? 1;

      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          final yIndex = y * yRowStride + x;
          final uvIndex = uvPixelStride * (x >> 1) + uvRowStride * (y >> 1);

          final yValue = yPlane[yIndex];
          final uValue = uPlane[uvIndex];
          final vValue = vPlane[uvIndex];

          final rgb = _yuvToRgb(yValue, uValue, vValue);
          image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
        }
      }
      return image;
    }

    final vuPlane = frame.planeBytes[1];
    final uvRowStride = frame.bytesPerRow[1];

    for (var y = 0; y < frame.height; y++) {
      for (var x = 0; x < frame.width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (x >> 1) * 2 + (y >> 1) * uvRowStride;

        final yValue = yPlane[yIndex];
        final vValue = vuPlane[uvIndex];
        final uValue = vuPlane[uvIndex + 1];

        final rgb = _yuvToRgb(yValue, uValue, vValue);
        image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return image;
  }

  static List<int> _yuvToRgb(int y, int u, int v) {
    final r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
    final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
    final b = (y + 1.772 * (u - 128)).round().clamp(0, 255);
    return [r, g, b];
  }
}
