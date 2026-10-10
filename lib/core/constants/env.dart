/// Provided at build time: --dart-define=PLACES_API_KEY=xxxx
abstract final class Env {
  static const placesApiKey = String.fromEnvironment('PLACES_API_KEY');
}
