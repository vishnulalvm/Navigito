import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws a round, white-bordered photo pin from a network image.
class MarkerIconBuilder {
  MarkerIconBuilder(this._dio);
  final Dio _dio;

  final _cache = <String, BitmapDescriptor>{};

  Future<BitmapDescriptor> circlePhoto(String url, {double size = 120}) async {
    final cached = _cache[url];
    if (cached != null) return cached;
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(res.data!),
        targetWidth: size.toInt(),
        targetHeight: size.toInt(),
      );
      final image = (await codec.getNextFrame()).image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);
      const border = 6.0;

      canvas.drawCircle(center, size / 2, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: center, radius: size / 2 - border)),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, size, size),
        Paint(),
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final out = await picture.toImage(size.toInt(), size.toInt());
      final bytes = (await out.toByteData(format: ui.ImageByteFormat.png))!;
      final icon = BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: size / 2.5,
        height: size / 2.5,
      );
      return _cache[url] = icon;
    } catch (_) {
      return BitmapDescriptor.defaultMarker;
    }
  }
}
