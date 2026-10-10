import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/trip_detail.dart';
import '../../domain/entities/trip_stop.dart';
import 'stop_style.dart';

/// Round, white-bordered pin with the stop type's icon.
Future<BitmapDescriptor> buildStopPin(StopType type, {bool big = false}) async {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const c = Offset(size / 2, size / 2);
  canvas.drawCircle(c, size / 2, Paint()..color = Colors.white);
  canvas.drawCircle(
    c,
    size / 2 - 6,
    Paint()
      ..color = type == StopType.start ? const Color(0xFF2F6BFF) : type.color,
  );
  final icon = type == StopType.start ? Icons.navigation : type.icon;
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 46,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
  return BitmapDescriptor.bytes(
    bytes.buffer.asUint8List(),
    width: big ? 44 : 36,
    height: big ? 44 : 36,
  );
}

Future<Set<Marker>> buildRouteMarkers(TripDetail trip) async {
  final markers = <Marker>{};
  for (final s in trip.stops) {
    markers.add(
      Marker(
        markerId: MarkerId(s.id),
        position: LatLng(s.latitude, s.longitude),
        icon: await buildStopPin(s.type, big: s == trip.stops.last),
        infoWindow: InfoWindow(title: s.title, snippet: s.subtitle),
      ),
    );
  }
  return markers;
}

List<LatLng> routePoints(TripDetail trip) => [
  for (final s in trip.stops) LatLng(s.latitude, s.longitude),
];

Polyline buildRoutePolyline(TripDetail trip, {List<LatLng>? path}) => Polyline(
  polylineId: const PolylineId('route'),
  points: path ?? routePoints(trip),
  color: const Color(0xFF3D8BFF),
  width: 5,
  jointType: JointType.round,
  startCap: Cap.roundCap,
  endCap: Cap.roundCap,
);

LatLngBounds boundsOf(List<LatLng> pts) {
  final lats = pts.map((p) => p.latitude);
  final lngs = pts.map((p) => p.longitude);
  return LatLngBounds(
    southwest: LatLng(
      lats.reduce((a, b) => a < b ? a : b),
      lngs.reduce((a, b) => a < b ? a : b),
    ),
    northeast: LatLng(
      lats.reduce((a, b) => a > b ? a : b),
      lngs.reduce((a, b) => a > b ? a : b),
    ),
  );
}
