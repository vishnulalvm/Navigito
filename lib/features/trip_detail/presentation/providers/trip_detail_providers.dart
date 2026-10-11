import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/supabase_api.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/domain/usecases/manage_my_trips.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../domain/entities/trip_comment.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/get_road_path.dart';
import '../../domain/usecases/get_trip_detail.dart';
import '../../domain/usecases/manage_trip_comments.dart';
import '../../domain/usecases/set_trip_reaction.dart';
import '../widgets/route_map_helpers.dart';

class TripDetailNotifier extends FamilyAsyncNotifier<TripDetail, String> {
  @override
  Future<TripDetail> build(String arg) async {
    // Liked/saved/following are per user: reload on sign in, out or switch.
    ref.watch(authUserProvider.select((u) => u.valueOrNull?.id));
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
    onSynced: (d) {
      ref.read(tripsProvider.notifier).patchLikes(d.id, d.likes);
      ref.invalidate(myTripsProvider(MyTripsTab.liked));
    },
  );

  Future<String?> toggleSave() => _optimistic(
    (d) => d.copyWith(isSaved: !d.isSaved),
    (d) => _react.save(d.id, d.isSaved),
    onSynced: (d) {
      ref.read(tripsProvider.notifier).patchSaved(d.id, d.isSaved);
      ref.invalidate(myTripsProvider(MyTripsTab.saved));
    },
  );

  Future<String?> toggleFollow() async {
    final trip = state.valueOrNull;
    if (trip != null && trip.authorId == SupabaseApi.userId) {
      return "You can't follow yourself";
    }
    return _optimistic(
      (d) => d.copyWith(isFollowing: !d.isFollowing),
      (d) => _react.follow(d.authorId, d.isFollowing),
    );
  }

  /// Keeps the comment count in step with the comments sheet.
  void adjustComments(int delta) {
    final trip = state.valueOrNull;
    if (trip == null) return;
    state = AsyncData(
      trip.copyWith(comments: (trip.comments + delta).clamp(0, 1 << 31)),
    );
  }

  /// Deletes the caller's own trip. Returns the error message, or null.
  Future<String?> delete() async {
    final result = await DeleteTrip(sl<MyTripsRepository>())(arg);
    return result.fold((f) => f.message, (_) {
      ref.read(tripsProvider.notifier).drop(arg);
      for (final tab in MyTripsTab.values) {
        ref.invalidate(myTripsProvider(tab));
      }
      return null;
    });
  }
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

/// A trip's comments, newest first, loaded a page at a time.
/// Dropped when the sheet closes, so reopening it shows fresh comments.
class TripCommentsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<TripComment>, String> {
  static const _pageSize = 30;

  bool _hasMore = true;
  bool _loadingMore = false;

  /// Whether older comments are left to load.
  bool get hasMore => _hasMore;

  ManageTripComments get _comments =>
      ManageTripComments(sl<TripDetailRepository>());

  @override
  Future<List<TripComment>> build(String arg) async {
    final result = await _comments.page(arg);
    final page = result.fold((f) => throw Exception(f.message), (c) => c);
    _hasMore = page.length >= _pageSize;
    return page;
  }

  Future<void> loadMore() async {
    final loaded = state.valueOrNull;
    if (loaded == null || loaded.isEmpty || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    final result = await _comments.page(arg, before: loaded.last.createdAt);
    _loadingMore = false;
    result.fold((f) => appLogger.w('Older comments failed: ${f.message}'), (
      older,
    ) {
      _hasMore = older.length >= _pageSize;
      final now = state.valueOrNull ?? const <TripComment>[];
      final seen = {for (final c in now) c.id};
      state = AsyncData([
        ...now,
        for (final c in older)
          if (!seen.contains(c.id)) c,
      ]);
    });
  }

  /// Posts [body] as the signed-in user. Returns the error message, or null.
  Future<String?> add(String body) async {
    final result = await _comments.add(arg, body);
    return result.fold((f) => f.message, (comment) {
      state = AsyncData([comment, ...?state.valueOrNull]);
      ref.read(tripDetailProvider(arg).notifier).adjustComments(1);
      return null;
    });
  }

  /// Removes it at once; puts it back if the server refuses. Returns the
  /// error message, or null on success.
  Future<String?> delete(TripComment comment) async {
    final before = state.valueOrNull;
    if (before == null) return null;
    final index = before.indexOf(comment);
    if (index < 0) return null;
    state = AsyncData([...before]..removeAt(index));
    ref.read(tripDetailProvider(arg).notifier).adjustComments(-1);

    final result = await _comments.delete(comment.id);
    return result.fold((f) {
      final now = state.valueOrNull ?? const <TripComment>[];
      state = AsyncData([...now]..insert(index.clamp(0, now.length), comment));
      ref.read(tripDetailProvider(arg).notifier).adjustComments(1);
      return f.message;
    }, (_) => null);
  }
}

final tripCommentsProvider = AsyncNotifierProvider.autoDispose
    .family<TripCommentsNotifier, List<TripComment>, String>(
      TripCommentsNotifier.new,
    );
