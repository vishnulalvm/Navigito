import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/get_road_path.dart';
import '../../domain/usecases/get_trip_detail.dart';
import '../widgets/route_map_helpers.dart';

class TripDetailNotifier extends FamilyAsyncNotifier<TripDetail, String> {
  @override
  Future<TripDetail> build(String arg) async {
    final result = await GetTripDetail(sl<TripDetailRepository>())(arg);
    return result.fold((f) => throw Exception(f.message), (d) => d);
  }

  void _update(TripDetail Function(TripDetail) fn) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(fn(current));
  }

  void toggleLike() => _update((d) => d.copyWith(isLiked: !d.isLiked));
  void toggleFollow() =>
      _update((d) => d.copyWith(isFollowing: !d.isFollowing));
  void toggleSave() => _update((d) => d.copyWith(isSaved: !d.isSaved));
}

final tripDetailProvider =
    AsyncNotifierProvider.family<TripDetailNotifier, TripDetail, String>(
      TripDetailNotifier.new,
    );

/// Road-following path for a trip, cached per trip id. Falls back to straight
/// lines between stops if the Routes API call fails.
final roadRouteProvider = FutureProvider.family<List<LatLng>, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripDetailProvider(tripId).future);
  final straight = routePoints(trip);

  final result = await GetRoadPath(sl<RouteRepository>())([
    for (final p in straight) (p.latitude, p.longitude),
  ]);
  return result.fold((failure) {
    appLogger.w('Routes API failed, using straight lines: ${failure.message}');
    return straight;
  }, (path) => [for (final p in path) LatLng(p.$1, p.$2)]);
});
