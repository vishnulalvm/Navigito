import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

/// Current user, or null when browsing signed out.
final authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final repo = sl<AuthRepository>();
  yield repo.currentUser;
  yield* repo.authChanges;
});

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authUserProvider).valueOrNull != null,
);

/// Apple on iOS/macOS, Google everywhere else (Android).
bool get usesAppleSignIn =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns true when a user is signed in afterwards.
  Future<bool> signIn() async {
    final repo = sl<AuthRepository>();
    state = const AsyncLoading();
    final result = usesAppleSignIn
        ? await SignInWithApple(repo)()
        : await SignInWithGoogle(repo)();
    state = result.fold(
      (f) => AsyncError(f.message, StackTrace.current),
      (_) => const AsyncData(null),
    );
    return repo.currentUser != null;
  }

  /// Returns the error message, or null once signed out.
  Future<String?> signOut() async {
    final result = await SignOut(sl<AuthRepository>())();
    return result.fold((f) => f.message, (_) => null);
  }

  /// Deletes the account for good and signs out. Returns the error message,
  /// or null on success.
  Future<String?> deleteAccount() async {
    final result = await DeleteAccount(sl<AuthRepository>())();
    return result.fold((f) => f.message, (_) => null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
