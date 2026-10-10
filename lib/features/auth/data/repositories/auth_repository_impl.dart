import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final AuthRemoteDatasource _remote;

  @override
  AuthUser? get currentUser => _remote.currentUser;

  @override
  Stream<AuthUser?> get authChanges => _remote.authChanges;

  @override
  Future<Either<Failure, Unit>> signInWithGoogle() =>
      _run(_remote.signInWithGoogle);

  @override
  Future<Either<Failure, Unit>> signInWithApple() =>
      _run(_remote.signInWithApple);

  @override
  Future<Either<Failure, Unit>> signOut() => _run(_remote.signOut);

  Future<Either<Failure, Unit>> _run(Future<void> Function() action) async {
    try {
      await action();
      return right(unit);
    } on GoogleSignInException catch (e) {
      // Closing the account picker is not an error worth showing.
      if (e.code == GoogleSignInExceptionCode.canceled) return right(unit);
      return left(ServerFailure(e.description ?? 'Google sign-in failed'));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return right(unit);
      return left(ServerFailure(e.message));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
