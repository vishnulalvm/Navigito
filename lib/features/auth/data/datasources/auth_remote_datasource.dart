import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/constants/env.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/auth_user.dart';

/// Native Google (Android) and Apple (iOS) sign-in exchanged for a Supabase
/// session via ID token.
class AuthRemoteDatasource {
  bool _googleReady = false;

  SupabaseClient get _client {
    if (Env.supabaseUrl.isEmpty) {
      throw const ServerException('Supabase is not configured');
    }
    return Supabase.instance.client;
  }

  static AuthUser? _map(User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return AuthUser(
      id: u.id,
      name:
          (meta['name'] ??
                  meta['full_name'] ??
                  u.email?.split('@').first ??
                  'Traveller')
              as String,
      email: u.email,
      avatarUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
    );
  }

  AuthUser? get currentUser =>
      Env.supabaseUrl.isEmpty ? null : _map(_client.auth.currentUser);

  Stream<AuthUser?> get authChanges => Env.supabaseUrl.isEmpty
      ? const Stream.empty()
      : _client.auth.onAuthStateChange.map((e) => _map(e.session?.user));

  Future<void> signInWithGoogle() async {
    if (Env.googleWebClientId.isEmpty) {
      throw const ServerException('GOOGLE_WEB_CLIENT_ID is not set');
    }
    final google = await _google();
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const ServerException('Google did not return an ID token');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signInWithApple() async {
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const ServerException('Apple did not return an ID token');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple only returns the name on first sign-in, so save it right away.
    final name = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().join(' ').trim();
    if (name.isNotEmpty) {
      await _client.auth.updateUser(UserAttributes(data: {'name': name}));
    }
  }

  /// Google Sign-In, initialised once. A session restored at launch never
  /// went through [signInWithGoogle], so sign-out may be the first use.
  Future<GoogleSignIn> _google() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: Env.googleWebClientId);
      _googleReady = true;
    }
    return google;
  }

  /// Ends the Supabase session (throws if that fails, e.g. offline, so the
  /// user knows they're still signed in), then forgets the Google account so
  /// the next sign-in asks which one to use.
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _forgetGoogle();
  }

  /// Deletes the account and everything in it. Photo files go first, through
  /// Storage (deleting rows in SQL would orphan them); then the account,
  /// which cascades to the profile, trips, likes, saves, follows, comments
  /// and notifications. Stops early, account intact, if a step fails.
  Future<void> deleteAccount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const ServerException('Sign in first');
    try {
      for (final bucket in const ['trip-photos', 'avatars']) {
        await _removeFolder(bucket, userId);
      }
      await _client.rpc('delete_account');
    } on StorageException catch (_) {
      throw const ServerException('Could not delete your photos. Try again.');
    } on PostgrestException catch (_) {
      throw const ServerException('Could not delete your account. Try again.');
    }
    // The account is gone; the server may refuse the now-orphaned session,
    // so make sure the local one ends regardless.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    await _forgetGoogle(disconnect: true);
  }

  /// Every file in the user's folder of [bucket], removed in pages.
  Future<void> _removeFolder(String bucket, String userId) async {
    final store = _client.storage.from(bucket);
    while (true) {
      final files = await store.list(
        path: userId,
        searchOptions: const SearchOptions(limit: 100),
      );
      if (files.isEmpty) return;
      await store.remove([for (final f in files) '$userId/${f.name}']);
    }
  }

  /// Best effort: Google isn't set up on iOS, and failing here must not
  /// undo a sign-out that already happened. [disconnect] also revokes the
  /// app's access, for a deleted account.
  Future<void> _forgetGoogle({bool disconnect = false}) async {
    if (Env.googleWebClientId.isEmpty) return;
    try {
      final google = await _google();
      disconnect ? await google.disconnect() : await google.signOut();
    } catch (_) {}
  }
}
