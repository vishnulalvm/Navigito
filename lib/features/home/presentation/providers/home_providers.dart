import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/marker_icon_builder.dart';
import '../../../../core/utils/session_token.dart';
import '../../../trip_detail/domain/entities/trip_detail.dart';
import '../../../trip_detail/domain/repositories/trip_detail_repository.dart';
import '../../../trip_detail/domain/usecases/get_trip_detail.dart';
import '../../../trip_detail/presentation/widgets/route_map_helpers.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/recent_place.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_map_places.dart';
import '../../domain/usecases/get_nearby_trips.dart';
import '../../domain/usecases/get_place_location.dart';
import '../../domain/usecases/recent_places.dart';
import '../../domain/usecases/search_places.dart';

final _repoProvider = Provider<HomeRepository>((_) => sl<HomeRepository>());

final currentPositionProvider = FutureProvider<Position?>(
  (_) => sl<LocationService>().currentPosition(),
);

/// True once the home map has been created and settled on its first camera.
/// The splash overlay waits for this so the user never sees a blank map.
final mapReadyProvider = StateProvider<bool>((_) => false);

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

enum TripFilter {
  nearby('Nearby'),
  trending('Trending'),
  oneDay('1 Day'),
  twoDays('2 Days'),
  threePlusDays('3+ Days');

  const TripFilter(this.label);
  final String label;

  List<Trip> apply(List<Trip> trips) => switch (this) {
    TripFilter.nearby => trips,
    TripFilter.trending => [
      ...trips,
    ]..sort((a, b) => b.likes.compareTo(a.likes)),
    TripFilter.oneDay => trips.where((t) => t.days == 1).toList(),
    TripFilter.twoDays => trips.where((t) => t.days == 2).toList(),
    TripFilter.threePlusDays => trips.where((t) => t.days >= 3).toList(),
  };
}

final tripFilterProvider = StateProvider<TripFilter>((_) => TripFilter.nearby);

/// Place picked from the search bar (e.g. "Munnar"); null = no place filter.
final searchedPlaceProvider = StateProvider<String?>((_) => null);

final filteredTripsProvider = Provider<AsyncValue<List<Trip>>>((ref) {
  final filter = ref.watch(tripFilterProvider);
  final place = ref.watch(searchedPlaceProvider)?.toLowerCase();

  return ref.watch(tripsProvider).whenData((trips) {
    // Dummy place match; the backend will do this with a geo query.
    final inPlace = place == null
        ? trips
        : trips
              .where(
                (t) =>
                    t.places.any((p) => place.contains(p) || p.contains(place)),
              )
              .toList();
    return filter.apply(inPlace);
  });
});

class SearchState {
  const SearchState({
    this.query = '',
    this.places = const [],
    this.loading = false,
    this.error,
  });

  final String query;

  /// Google results for the latest finished request. Kept while the next one
  /// loads, so the list doesn't flicker between keystrokes.
  final List<PlaceSuggestion> places;
  final bool loading;
  final String? error;

  /// Google is only asked from this many characters on.
  static const minRemoteLength = 3;

  bool get searchesRemote => query.trim().length >= minRemoteLength;

  SearchState copyWith({
    String? query,
    List<PlaceSuggestion>? places,
    bool? loading,
    String? Function()? error,
  }) => SearchState(
    query: query ?? this.query,
    places: places ?? this.places,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
  );
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  Timer? _debounce;

  /// One token per search session (typing → picking a place), so Google bills
  /// the session once instead of every autocomplete request.
  String? _sessionToken;

  HomeRepository get _repo => _ref.read(_repoProvider);

  void onQueryChanged(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);
    if (!state.searchesRemote) {
      state = state.copyWith(
        places: const [],
        loading: false,
        error: () => null,
      );
      return;
    }
    // Shown as loading from the first keystroke, so "No places found"
    // doesn't flash before the request even starts.
    state = state.copyWith(loading: true, error: () => null);
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  /// Runs the search for the current query now (also used by "Retry").
  Future<void> _search() async {
    final query = state.query;
    state = state.copyWith(loading: true, error: () => null);
    final pos = _ref.read(currentPositionProvider).valueOrNull;
    final result = await SearchPlaces(_repo)(
      query,
      sessionToken: _sessionToken ??= newSessionToken(),
      latitude: pos?.latitude,
      longitude: pos?.longitude,
    );
    // Drop answers to queries the user has already typed past.
    if (!mounted || query != state.query) return;
    state = result.fold(
      (f) => state.copyWith(loading: false, error: () => f.message),
      (places) => state.copyWith(loading: false, places: places),
    );
  }

  void retry() {
    _debounce?.cancel();
    if (state.searchesRemote) _search();
  }

  /// Resolves a Google suggestion to coordinates (ending the billing session)
  /// and remembers it, so picking it again is free.
  Future<LatLng?> select(PlaceSuggestion s) async {
    _debounce?.cancel();
    final result = await GetPlaceLocation(_repo)(
      s.placeId,
      sessionToken: _sessionToken,
    );
    _sessionToken = null;
    return result.fold((_) => null, (r) {
      _ref
          .read(recentPlacesProvider.notifier)
          .add(
            RecentPlace(
              placeId: s.placeId,
              name: s.mainText,
              secondaryText: s.secondaryText,
              latitude: r.$1,
              longitude: r.$2,
              savedAt: DateTime.now(),
            ),
          );
      return LatLng(r.$1, r.$2);
    });
  }

  void clear() {
    _debounce?.cancel();
    _sessionToken = null;
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>(
      SearchNotifier.new,
    );

class RecentPlacesNotifier extends Notifier<List<RecentPlace>> {
  @override
  List<RecentPlace> build() => GetRecentPlaces(ref.read(_repoProvider))();

  /// Moves [place] to the top (picking a recent again refreshes its age).
  void add(RecentPlace place) {
    state = [
      place,
      ...state.where((p) => p.placeId != place.placeId),
    ].take(5).toList();
    SaveRecentPlace(ref.read(_repoProvider))(place);
  }
}

final recentPlacesProvider =
    NotifierProvider<RecentPlacesNotifier, List<RecentPlace>>(
      RecentPlacesNotifier.new,
    );

/// Matches found without any API call: recent picks, the app's own map places
/// and trips. Shown above Google's results.
class LocalMatches {
  const LocalMatches({
    this.recents = const [],
    this.places = const [],
    this.trips = const [],
  });

  final List<RecentPlace> recents;
  final List<MapPlace> places;
  final List<Trip> trips;

  bool get isEmpty => recents.isEmpty && places.isEmpty && trips.isEmpty;
}

final localMatchesProvider = Provider.autoDispose<LocalMatches>((ref) {
  final query = ref
      .watch(searchProvider.select((s) => s.query))
      .trim()
      .toLowerCase();
  final recents = ref.watch(recentPlacesProvider);
  if (query.isEmpty) return LocalMatches(recents: recents);

  bool hit(String text) => text.toLowerCase().contains(query);
  final places = ref.watch(mapPlacesProvider).valueOrNull ?? const [];
  final trips = ref.watch(tripsProvider).valueOrNull ?? const [];
  return LocalMatches(
    recents: [
      for (final p in recents)
        if (hit(p.name) || hit(p.secondaryText)) p,
    ],
    places: [
      for (final p in places)
        if (hit(p.name)) p,
    ].take(3).toList(),
    trips: [
      for (final t in trips)
        if (hit(t.title) || t.places.any(hit)) t,
    ].take(3).toList(),
  );
});

/// The trip whose route is currently drawn on the home map (null = none).
class ActiveRouteNotifier extends AsyncNotifier<TripDetail?> {
  @override
  Future<TripDetail?> build() async => null;

  Future<void> show(String tripId) async {
    state = const AsyncLoading();
    final result = await GetTripDetail(sl<TripDetailRepository>())(tripId);
    state = result.fold(
      (f) => AsyncError(f.message, StackTrace.current),
      AsyncData.new,
    );
  }

  void clear() => state = const AsyncData(null);
}

final activeRouteProvider =
    AsyncNotifierProvider<ActiveRouteNotifier, TripDetail?>(
      ActiveRouteNotifier.new,
    );

final routeMarkersProvider = FutureProvider<Set<Marker>>((ref) async {
  final trip = ref.watch(activeRouteProvider).valueOrNull;
  if (trip == null) return const {};
  return buildRouteMarkers(trip);
});
