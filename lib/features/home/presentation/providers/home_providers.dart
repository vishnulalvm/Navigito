import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/marker_icon_builder.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_map_places.dart';
import '../../domain/usecases/get_nearby_trips.dart';
import '../../domain/usecases/get_place_location.dart';
import '../../domain/usecases/search_places.dart';

final _repoProvider = Provider<HomeRepository>((_) => sl<HomeRepository>());

final currentPositionProvider = FutureProvider<Position?>(
  (_) => sl<LocationService>().currentPosition(),
);

final mapTypeProvider = StateProvider<MapType>((_) => MapType.normal);

final mapPlacesProvider = FutureProvider<List<MapPlace>>((ref) async {
  final result = await GetMapPlaces(ref.watch(_repoProvider))();
  return result.getOrElse((_) => const []);
});

/// Marker icons for each place, built once the places have loaded.
final placeMarkersProvider = FutureProvider<Set<Marker>>((ref) async {
  final places = await ref.watch(mapPlacesProvider.future);
  final builder = sl<MarkerIconBuilder>();
  final markers = await Future.wait(
    places.map((p) async {
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.latitude, p.longitude),
        icon: await builder.circlePhoto(p.photoUrl),
        infoWindow: InfoWindow(title: p.name),
      );
    }),
  );
  return markers.toSet();
});

class TripsNotifier extends AsyncNotifier<List<Trip>> {
  @override
  Future<List<Trip>> build() async {
    final result = await GetNearbyTrips(ref.watch(_repoProvider))();
    return result.getOrElse((_) => const []);
  }

  void toggleFavorite(String id) {
    final trips = state.valueOrNull;
    if (trips == null) return;
    state = AsyncData([
      for (final t in trips)
        t.id == id ? t.copyWith(isFavorite: !t.isFavorite) : t,
    ]);
  }
}

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<Trip>>(
  TripsNotifier.new,
);

class SearchNotifier extends StateNotifier<AsyncValue<List<PlaceSuggestion>>> {
  SearchNotifier(this._repo) : super(const AsyncData([]));

  final HomeRepository _repo;
  Timer? _debounce;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = const AsyncData([]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      state = const AsyncLoading();
      final result = await SearchPlaces(_repo)(query);
      state = result.fold(
        (f) => AsyncError(f.message, StackTrace.current),
        AsyncData.new,
      );
    });
  }

  Future<LatLng?> select(PlaceSuggestion s) async {
    final result = await GetPlaceLocation(_repo)(s.placeId);
    state = const AsyncData([]);
    return result.fold((_) => null, (r) => LatLng(r.$1, r.$2));
  }

  void clear() {
    _debounce?.cancel();
    state = const AsyncData([]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider =
    StateNotifierProvider.autoDispose<
      SearchNotifier,
      AsyncValue<List<PlaceSuggestion>>
    >((ref) => SearchNotifier(ref.watch(_repoProvider)));
