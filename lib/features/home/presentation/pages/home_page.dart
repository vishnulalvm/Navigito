import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/home_providers.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/map_round_button.dart';
import '../widgets/trips_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _kochi = LatLng(9.9312, 76.2673);

  GoogleMapController? _map;

  Future<void> _goTo(LatLng target, {double zoom = 13}) =>
      _map?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom)) ??
      Future.value();

  Future<void> _goToMyLocation() async {
    final pos = await ref.read(currentPositionProvider.future);
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable. Check permission.'),
        ),
      );
      return;
    }
    _goTo(LatLng(pos.latitude, pos.longitude), zoom: 14);
  }

  void _cycleMapType() {
    const order = [MapType.normal, MapType.satellite, MapType.terrain];
    final current = ref.read(mapTypeProvider);
    ref.read(mapTypeProvider.notifier).state =
        order[(order.indexOf(current) + 1) % order.length];
  }

  @override
  Widget build(BuildContext context) {
    final navSpace = FloatingNavBar.reservedSpace(context);
    final mapType = ref.watch(mapTypeProvider);
    final markers = ref.watch(placeMarkersProvider).valueOrNull ?? const {};
    final position = ref.watch(currentPositionProvider).valueOrNull;
    final hasLocation = position != null;

    ref.listen(currentPositionProvider, (_, next) {
      final pos = next.valueOrNull;
      if (pos != null) _goTo(LatLng(pos.latitude, pos.longitude), zoom: 11);
    });

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            // Splash preloads the location, so the map opens right on the user.
            initialCameraPosition: CameraPosition(
              target: position == null
                  ? _kochi
                  : LatLng(position.latitude, position.longitude),
              zoom: position == null ? 10 : 12,
            ),
            mapType: mapType,
            markers: markers,
            myLocationEnabled: hasLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _map = c,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: HomeSearchBar(onPlaceSelected: _goTo),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 84,
            child: MapRoundButton(
              icon: Icons.layers_outlined,
              onPressed: _cycleMapType,
            ),
          ),
          Positioned(
            right: 16,
            bottom:
                (MediaQuery.sizeOf(context).height - navSpace) * 0.34 +
                navSpace +
                16,
            child: MapRoundButton(
              icon: Icons.my_location,
              onPressed: _goToMyLocation,
            ),
          ),
          // Keep the sheet above the floating navbar.
          Padding(
            padding: EdgeInsets.only(bottom: navSpace),
            child: const TripsSheet(),
          ),
        ],
      ),
    );
  }
}
