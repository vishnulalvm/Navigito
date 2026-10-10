import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/map_styles.dart';
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

// Kept alive so switching tabs doesn't destroy and re-create the native map.
class _RouteTabState extends ConsumerState<RouteTab>
    with AutomaticKeepAliveClientMixin {
  GoogleMapController? _map;
  Set<Marker> _markers = const {};
  MapType _type = MapType.normal;
  bool _framed = false;
  bool _ready = false;

  List<LatLng> get _points => routePoints(widget.trip);

  @override
  bool get wantKeepAlive => true;

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

  List<LatLng> get _framePoints =>
      ref.read(roadRouteProvider(widget.trip.id)).valueOrNull ?? _points;

  Future<void> _fit() async {
    final pts = _framePoints;
    if (_map == null || pts.isEmpty) return;
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(boundsOf(pts), 64));
  }

  /// Jumps straight to the route's bounds while the cover still hides the map,
  /// so tiles load once for the final view instead of for zoom 8 first.
  Future<void> _onMapCreated(GoogleMapController controller) async {
    _map = controller;
    final update = CameraUpdate.newLatLngBounds(boundsOf(_framePoints), 64);
    try {
      await controller.moveCamera(update);
    } catch (_) {
      // Bounds need the map laid out; retry once it has a size.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) await controller.moveCamera(update).catchError((_) {});
    }
    _framed = true;
    // In case the idle for the framed camera arrived before this point.
    Future.delayed(const Duration(milliseconds: 500), _reveal);
  }

  void _onCameraIdle() {
    if (_framed) _reveal();
  }

  void _reveal() {
    if (!_ready && mounted) setState(() => _ready = true);
  }

  void _cycleType() {
    const order = [MapType.normal, MapType.satellite, MapType.terrain];
    setState(() => _type = order[(order.indexOf(_type) + 1) % order.length]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bounds = boundsOf(_points);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
              (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
            ),
            zoom: 8,
          ),
          mapType: _type,
          style: isDark && _type == MapType.normal ? kDarkMapStyle : null,
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
          onMapCreated: _onMapCreated,
          onCameraIdle: _onCameraIdle,
        ),
        // Hides the native view's black surface until the first tiles are in.
        IgnorePointer(
          ignoring: _ready,
          child: AnimatedOpacity(
            opacity: _ready ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: ColoredBox(
              color: isDark ? kDarkMapBackground : kLightMapBackground,
              child: const SizedBox.expand(),
            ),
          ),
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
