import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../home/presentation/widgets/map_round_button.dart';
import '../../domain/entities/trip_detail.dart';
import '../providers/trip_detail_providers.dart';
import 'route_map_helpers.dart';

class RouteTab extends ConsumerStatefulWidget {
  const RouteTab({super.key, required this.trip});
  final TripDetail trip;

  @override
  ConsumerState<RouteTab> createState() => _RouteTabState();
}

class _RouteTabState extends ConsumerState<RouteTab> {
  GoogleMapController? _map;
  Set<Marker> _markers = const {};
  MapType _type = MapType.normal;

  List<LatLng> get _points => routePoints(widget.trip);

  @override
  void initState() {
    super.initState();
    _buildMarkers();
    // Re-frame once the road path arrives.
    ref.listenManual(roadRouteProvider(widget.trip.id), (_, next) {
      if (next.hasValue) _fit();
    });
  }

  Future<void> _buildMarkers() async {
    final markers = await buildRouteMarkers(widget.trip);
    if (mounted) setState(() => _markers = markers);
  }

  Future<void> _fit() async {
    final pts =
        ref.read(roadRouteProvider(widget.trip.id)).valueOrNull ?? _points;
    if (_map == null || pts.isEmpty) return;
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(boundsOf(pts), 64));
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
            buildRoutePolyline(
              widget.trip,
              path: ref.watch(roadRouteProvider(widget.trip.id)).valueOrNull,
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
