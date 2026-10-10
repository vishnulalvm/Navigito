import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  const SignInWithGoogle(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.signInWithGoogle();
}

class SignInWithApple {
  const SignInWithApple(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.signInWithApple();
}

class SignOut {
  const SignOut(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.signOut();
}

class DeleteAccount {
  const DeleteAccount(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.deleteAccount();
}
