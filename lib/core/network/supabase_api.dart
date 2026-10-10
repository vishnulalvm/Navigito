import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';
import '../error/exceptions.dart';

/// The Supabase client for datasources, with its errors turned into
/// [ServerException]s carrying a message fit to show the user.
abstract final class SupabaseApi {
  static SupabaseClient get client {
    if (Env.supabaseUrl.isEmpty) {
      throw const ServerException('Supabase is not configured');
    }
    return Supabase.instance.client;
  }

  /// The signed-in user's id, or null.
  static String? get userId =>
      Env.supabaseUrl.isEmpty ? null : client.auth.currentUser?.id;

  /// The signed-in user's id; throws when signed out.
  static String get requireUserId =>
      userId ?? (throw const ServerException('Sign in to continue'));

  static Future<T> run<T>(
    Future<T> Function(SupabaseClient client) body,
  ) async {
    try {
      return await body(client);
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(_message(e));
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      // Socket and HTTP client errors: the request never got an answer.
      throw const ServerException(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  static String _message(PostgrestException e) => switch (e.code) {
    '42501' => 'Sign in to do that',
    '23514' || '22023' => 'Some details are not valid',
    '23503' => 'That trip no longer exists',
    'PGRST301' || 'PGRST303' => 'Your session expired. Sign in again.',
    _ => 'Something went wrong. Try again.',
  };
}
