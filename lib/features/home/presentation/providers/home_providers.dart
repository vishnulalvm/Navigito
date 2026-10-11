import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/marker_icon_builder.dart';
import '../../../../core/utils/location_input.dart';
import '../../../../core/utils/plus_code.dart';
import '../../../../core/utils/session_token.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
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
import '../../domain/usecases/resolve_maps_link.dart';
import '../../domain/usecases/save_trip.dart';
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

/// Public trips for the home sheet: around a searched place when there is
/// one, otherwise nearest the user first.
class TripsNotifier extends AsyncNotifier<List<Trip>> {
  /// A searched place shows trips with a stop this close to it.
  static const _searchRadiusMeters = 40000;

  @override
  Future<List<Trip>> build() async {
    // Saved flags belong to the user, so signing in or out reloads.
    ref.watch(authUserProvider.select((u) => u.valueOrNull?.id));
    final searched = ref.watch(searchedLocationProvider);
    final here = searched == null
        ? await ref.watch(currentPositionProvider.future)
        : null;
    final result = await GetNearbyTrips(ref.watch(_repoProvider))(
      latitude: searched?.latitude ?? here?.latitude,
      longitude: searched?.longitude ?? here?.longitude,
      withinMeters: searched == null ? null : _searchRadiusMeters,
    );
    return result.fold((f) => throw Exception(f.message), (t) => t);
  }

  /// Saves or unsaves at once, then syncs; undoes it if the server refuses.
  /// Returns the error message, or null on success.
  Future<String?> toggleFavorite(String id) async {
    final trip = state.valueOrNull?.where((t) => t.id == id).firstOrNull;
    if (trip == null) return null;
    final saved = !trip.isFavorite;
    patchSaved(id, saved);
    final result = await SaveTrip(ref.read(_repoProvider))(id, saved);
    return result.fold(
      (f) {
        patchSaved(id, !saved);
        return f.message;
      },
      (_) {
        ref.invalidate(myTripsProvider(MyTripsTab.saved));
        return null;
      },
    );
  }

  /// Mirrors a save made elsewhere (trip screen, My Trips) on this list.
  void patchSaved(String id, bool saved) {
    final trips = state.valueOrNull;
    if (trips == null || !trips.any((t) => t.id == id)) return;
    state = AsyncData([
      for (final t in trips) t.id == id ? t.copyWith(isFavorite: saved) : t,
    ]);
  }

  /// Drops a deleted trip without reloading the feed.
  void drop(String id) {
    final trips = state.valueOrNull;
    if (trips == null) return;
    state = AsyncData([
      for (final t in trips)
        if (t.id != id) t,
    ]);
  }
}

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<Trip>>(
  TripsNotifier.new,
);

enum TripFilter {
  nearby('Nearby'),
  trending('Trending'),
  weekend('Weekend'),
  roadTrips('Road trips'),
  saved('Saved');

  const TripFilter(this.label);
  final String label;

  List<Trip> apply(List<Trip> trips) => switch (this) {
    TripFilter.nearby => trips,
    TripFilter.trending => [
      ...trips,
    ]..sort((a, b) => b.likes.compareTo(a.likes)),
    TripFilter.weekend => trips.where((t) => t.days <= 2).toList(),
    TripFilter.roadTrips => trips.where((t) => t.stops >= 4).toList(),
    TripFilter.saved => trips.where((t) => t.isFavorite).toList(),
  };
}

final tripFilterProvider = StateProvider<TripFilter>((_) => TripFilter.nearby);

/// Name of the place picked in the search bar (e.g. "Munnar"), for the
/// sheet's title; null = no place picked.
final searchedPlaceProvider = StateProvider<String?>((_) => null);

/// Where the picked place is; the feed then shows trips passing near it.
final searchedLocationProvider = StateProvider<LatLng?>((_) => null);

final filteredTripsProvider = Provider<AsyncValue<List<Trip>>>((ref) {
  final filter = ref.watch(tripFilterProvider);
  // The place itself is filtered by distance on the server.
  return ref.watch(tripsProvider).whenData(filter.apply);
});

/// A location typed or pasted directly (link, coordinates, plus code)
/// rather than searched for.
class DirectLocation {
  const DirectLocation({
    required this.source,
    this.position,
    this.name,
    this.resolving = false,
    this.error,
  });

  final LocationSource source;

  /// Null while [resolving] or after an [error].
  final LatLng? position;

  /// Place name, when a Maps link carries one.
  final String? name;

  /// A short link or short plus code is being looked up.
  final bool resolving;
  final String? error;
}

class SearchState {
  const SearchState({
    this.query = '',
    this.places = const [],
    this.loading = false,
    this.error,
    this.direct,
  });

  final String query;

  /// Set when [query] is a link, coordinates or a plus code; Google
  /// autocomplete is skipped then.
  final DirectLocation? direct;

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
    DirectLocation? Function()? direct,
  }) => SearchState(
    query: query ?? this.query,
    places: places ?? this.places,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
    direct: direct != null ? direct() : this.direct,
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
    final input = parseLocationInput(query);
    if (input != null) {
      _openDirect(input, query);
      return;
    }
    state = state.copyWith(direct: () => null);
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

  /// Turns a link, coordinates or plus code into a point, mostly without
  /// any API call. Only a link without coordinates falls back to searching
  /// the place it names.
  Future<void> _openDirect(LocationInput input, String query) async {
    bool stale() => !mounted || state.query != query;
    void show(DirectLocation direct) => state = state.copyWith(
      places: const [],
      loading: false,
      error: () => null,
      direct: () => direct,
    );

    switch (input) {
      case PointInput():
        show(
          DirectLocation(
            source: input.source,
            position: LatLng(input.latitude, input.longitude),
            name: input.name,
          ),
        );
      case ShortLinkInput(:final url):
        show(
          const DirectLocation(
            source: LocationSource.mapsLink,
            resolving: true,
          ),
        );
        final result = await ResolveMapsLink(_repo)(url.toString());
        if (stale()) return;
        final full = result.fold((_) => null, parseMapsUrl);
        if (full == null || full is ShortLinkInput) {
          show(
            const DirectLocation(
              source: LocationSource.mapsLink,
              error: 'Could not open this link',
            ),
          );
        } else {
          await _openDirect(full, query);
        }
      case LinkQueryInput(query: final name):
        state = state.copyWith(
          direct: () => null,
          loading: true,
          error: () => null,
        );
        await _search(text: name);
      case ShortPlusCodeInput(:final code, :final locality):
        show(
          const DirectLocation(
            source: LocationSource.plusCode,
            resolving: true,
          ),
        );
        final near = await _plusCodeReference(locality);
        if (stale()) return;
        if (near == null) {
          show(
            DirectLocation(
              source: LocationSource.plusCode,
              error: 'Add a town after the code, e.g. "$code Kochi"',
            ),
          );
          return;
        }
        final (lat, lng) = PlusCode.recoverNearest(code, near.$1, near.$2);
        show(
          DirectLocation(
            source: LocationSource.plusCode,
            position: LatLng(lat, lng),
          ),
        );
    }
  }

  /// Where a short plus code is near: the town written after it (one cached
  /// Places lookup), else the user.
  Future<(double, double)?> _plusCodeReference(String? locality) async {
    if (locality != null) {
      final token = newSessionToken();
      final found = await SearchPlaces(_repo)(locality, sessionToken: token);
      final first = found.fold((_) => null, (p) => p.firstOrNull);
      if (first != null) {
        final loc = await GetPlaceLocation(_repo)(
          first.placeId,
          sessionToken: token,
        );
        if (loc.getRight().toNullable() case final point?) return point;
      }
    }
    final pos = _ref.read(currentPositionProvider).valueOrNull;
    return pos == null ? null : (pos.latitude, pos.longitude);
  }

  /// Runs the search for the current query now (also used by "Retry").
  /// [text] searches something else for this query, e.g. the place a
  /// pasted link names.
  Future<void> _search({String? text}) async {
    final query = state.query;
    state = state.copyWith(loading: true, error: () => null);
    final pos = _ref.read(currentPositionProvider).valueOrNull;
    final result = await SearchPlaces(_repo)(
      text ?? query,
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
    if (parseLocationInput(state.query) case final input?) {
      _openDirect(input, state.query);
    } else if (state.searchesRemote) {
      _search();
    }
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
