import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authChanges;

  Future<Either<Failure, Unit>> signInWithGoogle();
  Future<Either<Failure, Unit>> signInWithApple();
  Future<Either<Failure, Unit>> signOut();
}
