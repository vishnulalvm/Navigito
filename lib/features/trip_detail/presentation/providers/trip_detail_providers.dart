import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/get_road_path.dart';
import '../../domain/usecases/get_trip_detail.dart';
import '../../domain/usecases/set_trip_reaction.dart';
import '../widgets/route_map_helpers.dart';

class TripDetailNotifier extends FamilyAsyncNotifier<TripDetail, String> {
  @override
  Future<TripDetail> build(String arg) async {
    final result = await GetTripDetail(sl<TripDetailRepository>())(arg);
    return result.fold((f) => throw Exception(f.message), (d) => d);
  }

  SetTripReaction get _react => SetTripReaction(sl<TripDetailRepository>());

  /// Shows [change] at once, then syncs it; puts the trip back if the server
  /// refuses. Returns the error message, or null on success.
  Future<String?> _optimistic(
    TripDetail Function(TripDetail) change,
    Future<Either<Failure, Unit>> Function(TripDetail updated) sync, {
    void Function(TripDetail updated)? onSynced,
  }) async {
    final before = state.valueOrNull;
    if (before == null) return null;
    final updated = change(before);
    state = AsyncData(updated);
    final result = await sync(updated);
    return result.fold(
      (f) {
        // Only undo if nothing newer replaced this change meanwhile.
        if (identical(state.valueOrNull, updated)) state = AsyncData(before);
        return f.message;
      },
      (_) {
        onSynced?.call(updated);
        return null;
      },
    );
  }

  Future<String?> toggleLike() => _optimistic(
    (d) => d.copyWith(
      isLiked: !d.isLiked,
      likes: (d.likes + (d.isLiked ? -1 : 1)).clamp(0, 1 << 31),
    ),
    (d) => _react.like(d.id, d.isLiked),
    onSynced: (_) => ref.invalidate(myTripsProvider(MyTripsTab.liked)),
  );

  Future<String?> toggleSave() => _optimistic(
    (d) => d.copyWith(isSaved: !d.isSaved),
    (d) => _react.save(d.id, d.isSaved),
    onSynced: (d) {
      ref.read(tripsProvider.notifier).patchSaved(d.id, d.isSaved);
      ref.invalidate(myTripsProvider(MyTripsTab.saved));
    },
  );

  Future<String?> toggleFollow() => _optimistic(
    (d) => d.copyWith(isFollowing: !d.isFollowing),
    (d) => _react.follow(d.authorId, d.isFollowing),
  );
}

final tripDetailProvider =
    AsyncNotifierProvider.family<TripDetailNotifier, TripDetail, String>(
      TripDetailNotifier.new,
    );

/// Road-following path for a trip, cached per trip id. Falls back to straight
/// lines between stops if the Routes API call fails.
///
/// Each run is a billed Routes API call, so it depends only on the stops'
/// coordinates: liking, following or saving the trip must not re-request it.
final roadRouteProvider = FutureProvider.family<List<LatLng>, String>((
  ref,
  tripId,
) async {
  await ref.watch(
    tripDetailProvider(tripId).selectAsync(
      (t) => [
        for (final p in routePoints(t)) '${p.latitude},${p.longitude}',
      ].join('|'),
    ),
  );
  final straight = routePoints(
    await ref.read(tripDetailProvider(tripId).future),
  );

  final result = await GetRoadPath(sl<RouteRepository>())([
    for (final p in straight) (p.latitude, p.longitude),
  ]);
  return result.fold((failure) {
    appLogger.w('Routes API failed, using straight lines: ${failure.message}');
    return straight;
  }, (path) => [for (final p in path) LatLng(p.$1, p.$2)]);
});
