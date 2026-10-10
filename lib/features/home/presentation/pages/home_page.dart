import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/map_styles.dart';
import '../../../trip_detail/domain/entities/trip_detail.dart';

import '../../../trip_detail/presentation/providers/trip_detail_providers.dart';
import '../../../trip_detail/presentation/widgets/route_map_helpers.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../providers/home_providers.dart';
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
  static const _initialSheetSize = 0.45;
  static const _searchAreaHeight = 84.0;

  final _sheetController = DraggableScrollableController();
  GoogleMapController? _map;

  /// Latest sheet extent (fraction of screen); null until the sheet reports.
  final _sheetSize = ValueNotifier<double?>(null);

  /// The controller can notify while the sheet is being built, and rebuilding
  /// a listener then throws, so defer the update to after the frame.
  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sheetSize.value = size;
      });
    } else {
      _sheetSize.value = size;
    }
  }

  // Latest layout values, kept for reacting to route changes outside build.
  double _minSize = 0.2;
  double _initialSize = _initialSheetSize;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
    ref.listenManual(
      activeRouteProvider,
      (_, next) => _onRouteChanged(next.valueOrNull),
    );
  }

  /// Collapse the sheet and frame the whole route on the map.
  Future<void> _onRouteChanged(TripDetail? trip) async {
    if (!_sheetController.isAttached) return;
    if (trip == null) {
      await _sheetController.animateTo(
        _initialSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    await _sheetController.animateTo(
      _minSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    // Frame the road path once the Routes API answers (straight stops if it
    // fails), unless the route was dismissed meanwhile.
    final path = await ref.read(roadRouteProvider(trip.id).future);
    if (!mounted || ref.read(activeRouteProvider).valueOrNull?.id != trip.id) {
      return;
    }
    await _map?.animateCamera(CameraUpdate.newLatLngBounds(boundsOf(path), 56));
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetSize.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// First idle after creation means the initial camera and tiles are in.
  void _onMapSettled() {
    if (ref.read(mapReadyProvider)) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(mapReadyProvider.notifier).state = true;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final navSpace = FloatingNavBar.reservedSpace(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final route = ref.watch(activeRouteProvider).valueOrNull;
    final markers = route != null
        ? ref.watch(routeMarkersProvider).valueOrNull ?? const <Marker>{}
        : ref.watch(placeMarkersProvider).valueOrNull ?? const <Marker>{};
    final positionAsync = ref.watch(currentPositionProvider);
    final position = positionAsync.valueOrNull;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;

          // The collapsed sheet shows its header just above the navbar.
          final minSize = ((navSpace + kTripsSheetHeaderHeight) / height).clamp(
            0.1,
            0.5,
          );
          // Fully expanded, the sheet stops just under the search bar.
          final maxSize = (1 - (topInset + _searchAreaHeight) / height).clamp(
            0.6,
            1.0,
          );
          final initialSize = _initialSheetSize.clamp(minSize, maxSize);
          _minSize = minSize;
          _initialSize = initialSize;

          return Stack(
            children: [
              // Built only once the location has resolved, so the camera
              // starts on the user and never jumps.
              if (positionAsync.isLoading)
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: const SizedBox.expand(),
                )
              else
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: position == null
                        ? _kochi
                        : LatLng(position.latitude, position.longitude),
                    zoom: position == null ? 10 : 12,
                  ),
                  style: Theme.of(context).brightness == Brightness.dark
                      ? kDarkMapStyle
                      : null,
                  markers: markers,
                  polylines: {
                    if (route != null)
                      buildRoutePolyline(
                        route,
                        path: ref
                            .watch(roadRouteProvider(route.id))
                            .valueOrNull,
                      ),
                  },
                  // Keeps the map's focus area clear of the search bar and
                  // the collapsed sheet.
                  padding: EdgeInsets.only(
                    top: topInset + _searchAreaHeight,
                    bottom: minSize * height,
                  ),
                  myLocationEnabled: position != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (c) => _map = c,
                  onCameraIdle: _onMapSettled,
                ),
              TripsSheet(
                controller: _sheetController,
                minSize: minSize,
                initialSize: initialSize,
                maxSize: maxSize,
                bottomInset: navSpace + 16,
                onShowRoute: (id) =>
                    ref.read(activeRouteProvider.notifier).show(id),
              ),
              // Rides on top of the sheet; hides once the sheet reaches the top.
              ValueListenableBuilder<double?>(
                valueListenable: _sheetSize,
                builder: (context, reported, _) {
                  final size = reported ?? initialSize;
                  final atTop = size >= maxSize - 0.03;
                  return Positioned(
                    right: 16,
                    bottom: size * height + 12,
                    child: IgnorePointer(
                      ignoring: atTop,
                      child: AnimatedOpacity(
                        opacity: atTop ? 0 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: MapRoundButton(
                          icon: Icons.my_location,
                          onPressed: _goToMyLocation,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (route != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: topInset + 78,
                  child: _RouteBanner(
                    trip: route,
                    onClose: ref.read(activeRouteProvider.notifier).clear,
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: HomeSearchBar(onPlaceSelected: _goTo),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteBanner extends StatelessWidget {
  const _RouteBanner({required this.trip, required this.onClose});

  final TripDetail trip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.primaryContainer,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.route, color: scheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${trip.title} · ${trip.distanceKm} km',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
