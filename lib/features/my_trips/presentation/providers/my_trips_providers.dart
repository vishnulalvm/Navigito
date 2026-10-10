import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/domain/entities/trip.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../../../home/domain/usecases/save_trip.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../trip_detail/domain/repositories/trip_detail_repository.dart';
import '../../../trip_detail/domain/usecases/set_trip_reaction.dart';
import '../../domain/repositories/my_trips_repository.dart';
import '../../domain/usecases/get_my_trips.dart';
import '../../domain/usecases/manage_my_trips.dart';

final myTripsTabProvider = StateProvider<MyTripsTab>((_) => MyTripsTab.saved);

/// One tab of My Trips. Loaded when first shown and reloaded after it's
/// invalidated elsewhere (a save on home, a new trip), or on sign in/out.
class MyTripsNotifier extends FamilyAsyncNotifier<List<Trip>, MyTripsTab> {
  @override
  Future<List<Trip>> build(MyTripsTab arg) async {
    final userId = ref.watch(authUserProvider.select((u) => u.valueOrNull?.id));
    if (userId == null) return const [];
    final result = await GetMyTrips(sl<MyTripsRepository>())(arg);
    return result.fold((f) => throw Exception(f.message), (t) => t);
  }

  /// Saves or unsaves at once, then syncs; undoes it if the server refuses.
  /// Returns the error message, or null on success.
  Future<String?> toggleFavorite(String id) async {
    final trip = state.valueOrNull?.where((t) => t.id == id).firstOrNull;
    if (trip == null) return null;
    final saved = !trip.isFavorite;
    _patch(id, saved);
    final result = await SaveTrip(sl<HomeRepository>())(id, saved);
    return result.fold(
      (f) {
        _patch(id, !saved);
        return f.message;
      },
      (_) {
        ref.read(tripsProvider.notifier).patchSaved(id, saved);
        if (arg != MyTripsTab.saved) {
          ref.invalidate(myTripsProvider(MyTripsTab.saved));
        }
        return null;
      },
    );
  }

  /// Takes a trip off this tab: unsaves, unlikes, or (on Mine) deletes it.
  /// It disappears at once and comes back if the server refuses. Returns the
  /// error message, or null on success.
  Future<String?> remove(String id) async {
    final trips = state.valueOrNull;
    final index = trips?.indexWhere((t) => t.id == id) ?? -1;
    if (trips == null || index < 0) return null;
    state = AsyncData([...trips]..removeAt(index));

    final Either<Failure, Unit> result = switch (arg) {
      MyTripsTab.saved => await SaveTrip(sl<HomeRepository>())(id, false),
      MyTripsTab.liked => await SetTripReaction(
        sl<TripDetailRepository>(),
      ).like(id, false),
      MyTripsTab.mine => await DeleteTrip(sl<MyTripsRepository>())(id),
    };
    return result.fold(
      (f) {
        final now = state.valueOrNull ?? const <Trip>[];
        state = AsyncData(
          [...now]..insert(index.clamp(0, now.length), trips[index]),
        );
        return f.message;
      },
      (_) {
        final home = ref.read(tripsProvider.notifier);
        switch (arg) {
          case MyTripsTab.saved:
            home.patchSaved(id, false);
          case MyTripsTab.liked:
            break;
          case MyTripsTab.mine:
            home.drop(id);
            ref
              ..invalidate(myTripsProvider(MyTripsTab.saved))
              ..invalidate(myTripsProvider(MyTripsTab.liked));
        }
        return null;
      },
    );
  }

  void _patch(String id, bool saved) {
    final trips = state.valueOrNull;
    if (trips == null) return;
    state = AsyncData([
      for (final t in trips) t.id == id ? t.copyWith(isFavorite: saved) : t,
    ]);
  }
}

final myTripsProvider =
    AsyncNotifierProvider.family<MyTripsNotifier, List<Trip>, MyTripsTab>(
      MyTripsNotifier.new,
    );
