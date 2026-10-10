/// Provided at build time: --dart-define-from-file=env.json
abstract final class Env {
  /// OAuth *Web* client ID from Google Cloud (used by Android Google sign-in).
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Publishable (anon) key. Safe in the app because row-level security guards
  /// the data. Never put the service_role key here.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const placesApiKey = String.fromEnvironment('PLACES_API_KEY');

  static const _routesApiKey = String.fromEnvironment('ROUTES_API_KEY');

  /// Falls back to the Places key when no dedicated Routes key is set.
  static String get routesApiKey =>
      _routesApiKey.isNotEmpty ? _routesApiKey : placesApiKey;
}
