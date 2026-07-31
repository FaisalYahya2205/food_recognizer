import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraFrameBuffer {
  CameraFrameBuffer({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
  });

  factory CameraFrameBuffer.capture(CameraImage source) {
    return CameraFrameBuffer(
      width: source.width,
      height: source.height,
      format: source.format.group,
      planes: source.planes.map((p) => Uint8List.fromList(p.bytes)).toList(),
      rowStrides: source.planes.map((p) => p.bytesPerRow).toList(),
      pixelStrides: source.planes.map((p) => p.bytesPerPixel).toList(),
    );
  }

  final int width;
  final int height;
  final ImageFormatGroup format;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int?> pixelStrides;
}

abstract final class YuvFrameDecoder {
  static img.Image? decode(CameraFrameBuffer buffer) {
    return switch (buffer.format) {
      ImageFormatGroup.bgra8888 => _decodeBgra(buffer),
      ImageFormatGroup.yuv420 || ImageFormatGroup.nv21 => _decodeYuv(buffer),
      _ => null,
    };
  }

  static img.Image? _decodeBgra(CameraFrameBuffer buffer) {
    if (buffer.planes.isEmpty) return null;
    return img.Image.fromBytes(
      width: buffer.width,
      height: buffer.height,
      bytes: buffer.planes.first.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image? _decodeYuv(CameraFrameBuffer buffer) {
    if (buffer.planes.length < 2) return null;

    final yPlane = buffer.planes[0];
    final yStride = buffer.rowStrides[0];
    final output = img.Image(width: buffer.width, height: buffer.height);

    if (buffer.planes.length >= 3) {
      final uPlane = buffer.planes[1];
      final vPlane = buffer.planes[2];
      final uvStride = buffer.rowStrides[1];
      final uvPixel = buffer.pixelStrides[1] ?? 1;

      for (var row = 0; row < buffer.height; row++) {
        for (var col = 0; col < buffer.width; col++) {
          final yIdx = row * yStride + col;
          final uvIdx = uvPixel * (col >> 1) + uvStride * (row >> 1);
          final rgb = _toRgb(yPlane[yIdx], uPlane[uvIdx], vPlane[uvIdx]);
          output.setPixelRgb(col, row, rgb[0], rgb[1], rgb[2]);
        }
      }
      return output;
    }

    final vuPlane = buffer.planes[1];
    final uvStride = buffer.rowStrides[1];
    for (var row = 0; row < buffer.height; row++) {
      for (var col = 0; col < buffer.width; col++) {
        final yIdx = row * yStride + col;
        final uvIdx = (col >> 1) * 2 + (row >> 1) * uvStride;
        final rgb = _toRgb(yIdx < yPlane.length ? yPlane[yIdx] : 0, vuPlane[uvIdx + 1], vuPlane[uvIdx]);
        output.setPixelRgb(col, row, rgb[0], rgb[1], rgb[2]);
      }
    }
    return output;
  }

  static List<int> _toRgb(int y, int u, int v) {
    final r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
    final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
    final b = (y + 1.772 * (u - 128)).round().clamp(0, 255);
    return [r, g, b];
  }
}
