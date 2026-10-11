import 'package:equatable/equatable.dart';

/// A trip being travelled: when it started and when each stop was reached.
class JourneyProgress extends Equatable {
  const JourneyProgress({
    required this.tripId,
    required this.startedAt,
    this.reachedAt = const {},
  });

  final String tripId;
  final DateTime startedAt;

  /// Stop id -> when the user marked it reached.
  final Map<String, DateTime> reachedAt;

  bool isReached(String stopId) => reachedAt.containsKey(stopId);

  JourneyProgress reach(String stopId, DateTime at) => JourneyProgress(
    tripId: tripId,
    startedAt: startedAt,
    reachedAt: {...reachedAt, stopId: at},
  );

  JourneyProgress unreach(String stopId) => JourneyProgress(
    tripId: tripId,
    startedAt: startedAt,
    reachedAt: {...reachedAt}..remove(stopId),
  );

  @override
  List<Object?> get props => [tripId, startedAt, reachedAt];
}
