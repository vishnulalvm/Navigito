import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show GoogleMapsFlutterPlatform, PointOfInterestTapEvent;

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/map_camera_cache.dart';
import '../../../../core/theme/map_styles.dart';
import '../../../../core/widgets/dropped_pin.dart';
import '../../../../core/widgets/map_sheet.dart';
import '../../../home/domain/entities/place_info.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../../../home/domain/usecases/get_place_info.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../home/presentation/widgets/home_search_bar.dart';
import '../../../home/presentation/widgets/map_round_button.dart';
import '../../../trip_detail/presentation/widgets/route_map_helpers.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';
import '../providers/trip_draft_provider.dart';
import '../widgets/draft_stops_sheet.dart';

/// Step 1 of creating a trip: search places one after another and drop them
/// on the map, in visiting order.
class AddTripPage extends ConsumerStatefulWidget {
  const AddTripPage({super.key});

  @override
  ConsumerState<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends ConsumerState<AddTripPage> {
  static const _kochi = LatLng(9.9312, 76.2673);

  final _sheet = MapSheetController(initialFraction: 0.4);
  late final CameraPosition? _cachedCamera = sl<MapCameraCache>().read();
  GoogleMapController? _map;

  Set<Marker> _markers = const {};
  String? _lastAddedId;

  /// Where typed coordinates or a pasted link point, before it's added.
  LatLng? _preview;

  /// Where the user tapped empty map; added with the card's button.
  LatLng? _dropped;

  /// A place label tapped on the map: its id while its details load, then
  /// the place. Android only; iOS taps drop a plain pin.
  String? _placeLoadingId;
  PlaceInfo? _place;
  StreamSubscription<PointOfInterestTapEvent>? _placeTaps;

  /// Drawn pins by type and number; drawing one takes a frame or two.
  final _pins = <String, BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      tripDraftProvider.select((d) => d.stops),
      (_, stops) => _refreshMarkers(stops),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _placeTaps?.cancel();
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _refreshMarkers(List<DraftStop> stops) async {
    final markers = <Marker>{};
    for (final (i, s) in stops.indexed) {
      final key = '${s.type.name}-${i + 1}';
      final icon = _pins[key] ??= await buildStopPin(s.type, label: '${i + 1}');
      markers.add(
        Marker(
          markerId: MarkerId(s.id),
          position: s.position,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: s.name),
          onTap: () => _focusStop(s),
        ),
      );
    }
    // A newer list may have finished drawing first.
    if (mounted && identical(stops, ref.read(tripDraftProvider).stops)) {
      setState(() => _markers = markers);
    }
  }

  void _onPicked(PickedPlace place) {
    final added = ref
        .read(tripDraftProvider.notifier)
        .addStop(
          DraftStop(
            id: place.id,
            name: place.name,
            subtitle: place.subtitle,
            position: place.position,
            type: stopTypeFor(place.types),
          ),
        );
    if (!added) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${place.name} is already in your trip')),
        );
      _goTo(place.position);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _lastAddedId = place.id);
    if (_sheet.currentSize > _sheet.initialSize) _sheet.rest();
    _frameStops();
  }

  /// Fits every stop on screen, above the resting sheet.
  Future<void> _frameStops() async {
    final points = [
      for (final s in ref.read(tripDraftProvider).stops) s.position,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) return _goTo(points.first);
    await _map?.animateCamera(
      CameraUpdate.newLatLngBounds(boundsOf(points), 64),
    );
  }

  Future<void> _focusStop(DraftStop stop) async {
    await _goTo(stop.position, zoom: 14);
    await _map?.showMarkerInfoWindow(MarkerId(stop.id));
  }

  Future<void> _goTo(LatLng target, {double zoom = 13}) async =>
      _map?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));

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

  void _onPreview(LatLng? position) {
    setState(() {
      _preview = position;
      if (position != null) _clearPick();
    });
    if (position != null) _goTo(position, zoom: 15);
  }

  void _onMapTap(LatLng position) {
    // A tap that only closes the keyboard shouldn't drop a pin too.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _clearPick();
      _dropped = position;
      _preview = null;
    });
  }

  /// One Place Details call (cached) turns the tapped label's id into its
  /// name, position and kind.
  Future<void> _onPlaceTap(PointOfInterestTapEvent event) async {
    final id = event.value.value;
    HapticFeedback.selectionClick();
    setState(() {
      _clearPick();
      _preview = null;
      _placeLoadingId = id;
    });
    final result = await GetPlaceInfo(sl<HomeRepository>())(id);
    if (!mounted || _placeLoadingId != id) return;
    result.fold(
      (_) {
        setState(() => _placeLoadingId = null);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not load this place')),
          );
      },
      (place) => setState(() {
        _placeLoadingId = null;
        _place = place;
      }),
    );
  }

  /// Forgets the dropped pin or tapped place (call inside setState).
  void _clearPick() {
    _dropped = null;
    _place = null;
    _placeLoadingId = null;
  }

  void _addPlace() {
    final place = _place;
    if (place == null) return;
    setState(_clearPick);
    _onPicked(
      PickedPlace(
        id: place.placeId,
        name: place.name,
        subtitle: place.address,
        position: LatLng(place.latitude, place.longitude),
        types: place.types,
      ),
    );
  }

  void _addDropped() {
    final pos = _dropped;
    if (pos == null) return;
    setState(() => _dropped = null);
    _onPicked(
      PickedPlace(
        id:
            'geo:${pos.latitude.toStringAsFixed(6)},'
            '${pos.longitude.toStringAsFixed(6)}',
        name: formatLatLng(pos),
        subtitle: 'Dropped pin',
        position: pos,
      ),
    );
  }

  Widget _pickCard() {
    final place = _place;
    if (place != null) {
      return DroppedPinCard(
        position: LatLng(place.latitude, place.longitude),
        title: place.name,
        subtitle: place.address.isEmpty ? null : place.address,
        icon: stopTypeFor(place.types).icon,
        actionLabel: 'Add stop',
        onAction: _addPlace,
        onClose: () => setState(_clearPick),
      );
    }
    return DroppedPinCard(
      position: _dropped,
      loading: _placeLoadingId != null,
      subtitle: _placeLoadingId != null ? 'Getting its details' : null,
      actionLabel: 'Add stop',
      onAction: _addDropped,
      onClose: () => setState(_clearPick),
    );
  }

  void _next() {
    ref.read(tripDraftProvider.notifier).planIfNeeded();
    context.push(AppRouter.addTripTimeline);
  }

  /// The draft stays in memory, so closing loses nothing.
  void _close() =>
      context.canPop() ? context.pop() : context.go(AppRouter.home);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final position = ref.watch(currentPositionProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stops = ref.watch(tripDraftProvider.select((d) => d.stops));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          _sheet.layout(
            height: height,
            topInset: media.padding.top,
            bottomSpace: media.padding.bottom,
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition:
                    _cachedCamera ??
                    CameraPosition(
                      target: position == null
                          ? _kochi
                          : LatLng(position.latitude, position.longitude),
                      zoom: position == null ? 10 : 12,
                    ),
                style: isDark ? kDarkMapStyle : null,
                markers: {
                  ..._markers,
                  if (_place case final place?)
                    previewMarker(
                      LatLng(place.latitude, place.longitude),
                      title: place.name,
                    )
                  else if (_dropped ?? _preview case final pin?)
                    previewMarker(
                      pin,
                      title: _dropped != null ? 'Dropped pin' : 'Preview',
                    ),
                },
                // Straight, dashed: the order of visits, not the roads yet.
                polylines: {
                  if (stops.length > 1)
                    Polyline(
                      polylineId: const PolylineId('draft'),
                      points: [for (final s in stops) s.position],
                      color: const Color(0xFF3D8BFF),
                      width: 4,
                      patterns: [PatternItem.dash(18), PatternItem.gap(10)],
                      jointType: JointType.round,
                    ),
                },
                // Frames pins between the search bar and the resting sheet.
                padding: EdgeInsets.only(
                  top: media.padding.top + kMapSearchAreaHeight,
                  bottom: _sheet.initialSize * height,
                ),
                myLocationEnabled: position != null,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onTap: _onMapTap,
                onMapCreated: (c) {
                  _map = c;
                  _placeTaps?.cancel();
                  _placeTaps = GoogleMapsFlutterPlatform.instance
                      .onPointOfInterestTap(mapId: c.mapId)
                      .listen(_onPlaceTap);
                  // Coming back to a draft, show what's already there.
                  if (stops.isNotEmpty) _frameStops();
                },
              ),
              DraftStopsSheet(
                controller: _sheet,
                bottomInset: media.padding.bottom + 16,
                lastAddedId: _lastAddedId,
                onNext: _next,
                onStopTap: _focusStop,
              ),
              if (_place != null || _placeLoadingId != null || _dropped != null)
                MapSheetFab(
                  key: const ValueKey('picked'),
                  controller: _sheet,
                  screenHeight: height,
                  left: 16,
                  child: TweenAnimationBuilder<double>(
                    // Re-keyed per pick so each one pops in; a place keeps
                    // its key from loading to loaded.
                    key: ValueKey(
                      _place?.placeId ?? _placeLoadingId ?? _dropped,
                    ),
                    tween: Tween(begin: 0.85, end: 1),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: _pickCard(),
                  ),
                )
              else
                MapSheetFab(
                  controller: _sheet,
                  screenHeight: height,
                  child: MapRoundButton(
                    icon: Icons.my_location,
                    onPressed: _goToMyLocation,
                  ),
                ),
              MapSearchBackdrop(controller: _sheet),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CloseButton(dock: _sheet.dock, onPressed: _close),
                      const SizedBox(width: 10),
                      Expanded(
                        child: HomeSearchBar(
                          stopPicker: true,
                          hintText: 'Search a place to add',
                          onPlaceSelected: _onPicked,
                          onPreview: _onPreview,
                          dock: _sheet.dock,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Round ✕ beside the search bar; flattens with it as the sheet docks.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.dock, required this.onPressed});

  final ValueNotifier<double> dock;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: dock,
      builder: (context, dock, _) => Material(
        color: Color.lerp(scheme.surface, scheme.surfaceContainerHigh, dock),
        elevation: 3 * (1 - dock),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 52,
            child: Tooltip(
              message: 'Close',
              child: Icon(Icons.close, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
