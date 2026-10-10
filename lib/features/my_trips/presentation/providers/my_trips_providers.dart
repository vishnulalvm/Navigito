import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../home/domain/entities/trip.dart';
import '../../domain/repositories/my_trips_repository.dart';
import '../../domain/usecases/get_my_trips.dart';

final myTripsTabProvider = StateProvider<MyTripsTab>((_) => MyTripsTab.saved);

class MyTripsNotifier extends FamilyAsyncNotifier<List<Trip>, MyTripsTab> {
  @override
  Future<List<Trip>> build(MyTripsTab arg) async {
    final result = await GetMyTrips(sl<MyTripsRepository>())(arg);
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

  void add(Trip trip) {
    final trips = state.valueOrNull ?? const <Trip>[];
    state = AsyncData([trip, ...trips]);
  }

  void remove(String id) {
    final trips = state.valueOrNull;
    if (trips == null) return;
    state = AsyncData(trips.where((t) => t.id != id).toList());
  }
}

final myTripsProvider =
    AsyncNotifierProvider.family<MyTripsNotifier, List<Trip>, MyTripsTab>(
      MyTripsNotifier.new,
    );
