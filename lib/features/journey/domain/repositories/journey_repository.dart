import '../entities/journey_progress.dart';

/// Journeys in progress, kept on the device so leaving the screen or closing
/// the app doesn't lose them.
abstract interface class JourneyRepository {
  JourneyProgress? read(String tripId);
  Future<void> save(JourneyProgress progress);
  Future<void> clear(String tripId);
}
