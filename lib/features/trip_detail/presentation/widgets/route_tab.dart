import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../home/presentation/widgets/map_round_button.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/entities/trip_stop.dart';
import 'stop_style.dart';

class RouteTab extends StatefulWidget {
  const RouteTab({super.key, required this.trip});
  final TripDetail trip;

  @override
  State<RouteTab> createState() => _RouteTabState();
}

class _RouteTabState extends State<RouteTab> {
  GoogleMapController? _map;
  Set<Marker> _markers = const {};
  MapType _type = MapType.normal;

  List<LatLng> get _points => [
    for (final s in widget.trip.stops) LatLng(s.latitude, s.longitude),
  ];

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  Future<void> _buildMarkers() async {
    final stops = widget.trip.stops;
    final markers = <Marker>{};
    for (final s in stops) {
      final isEnd = s == stops.last;
      markers.add(
        Marker(
          markerId: MarkerId(s.id),
          position: LatLng(s.latitude, s.longitude),
          icon: await _pin(s.type, isEnd),
          infoWindow: InfoWindow(title: s.title, snippet: s.subtitle),
        ),
      );
    }
    if (mounted) setState(() => _markers = markers);
  }

  Future<BitmapDescriptor> _pin(StopType type, bool big) async {
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
    final img = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: big ? 44 : 36,
      height: big ? 44 : 36,
    );
  }

  Future<void> _fit() async {
    final pts = _points;
    if (_map == null || pts.isEmpty) return;
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  void _cycleType() {
    const order = [MapType.normal, MapType.satellite, MapType.terrain];
    setState(() => _type = order[(order.indexOf(_type) + 1) % order.length]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _points.first, zoom: 8),
          mapType: _type,
          markers: _markers,
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _points,
              color: const Color(0xFF3D8BFF),
              width: 5,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          onMapCreated: (c) {
            _map = c;
            Future.delayed(const Duration(milliseconds: 300), _fit);
          },
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            children: [
              MapRoundButton(
                icon: Icons.layers_outlined,
                onPressed: _cycleType,
              ),
              const SizedBox(height: 12),
              MapRoundButton(icon: Icons.near_me_outlined, onPressed: _fit),
            ],
          ),
        ),
      ],
    );
  }
}
