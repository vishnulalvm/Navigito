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
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: Env.googleWebClientId);
      _googleReady = true;
    }
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

  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _client.auth.signOut();
  }
}
