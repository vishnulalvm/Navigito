import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../domain/entities/journey_progress.dart';
import '../../domain/repositories/journey_repository.dart';

/// The journey along a trip, or null when it isn't being travelled.
class JourneyNotifier extends FamilyNotifier<JourneyProgress?, String> {
  JourneyRepository get _repo => sl<JourneyRepository>();

  @override
  JourneyProgress? build(String arg) => _repo.read(arg);

  void _set(JourneyProgress? next) {
    state = next;
    next == null ? _repo.clear(arg) : _repo.save(next);
  }

  /// Starts the journey unless one is already under way.
  void start() {
    if (state == null) {
      _set(JourneyProgress(tripId: arg, startedAt: DateTime.now()));
    }
  }

  void reach(String stopId) {
    start();
    _set(state!.reach(stopId, DateTime.now()));
  }

  void unreach(String stopId) {
    final p = state;
    if (p != null) _set(p.unreach(stopId));
  }

  void end() => _set(null);
}

final journeyProvider =
    NotifierProvider.family<JourneyNotifier, JourneyProgress?, String>(
      JourneyNotifier.new,
    );

/// The first stop, in trip order, not yet reached; null once all are.
TripStop? nextStop(List<TripStop> stops, JourneyProgress? progress) =>
    stops.where((s) => !(progress?.isReached(s.id) ?? false)).firstOrNull;
