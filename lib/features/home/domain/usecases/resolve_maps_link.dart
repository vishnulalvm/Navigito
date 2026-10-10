import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/home_repository.dart';

class ResolveMapsLink {
  const ResolveMapsLink(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, String>> call(String url) =>
      _repository.resolveMapsLink(url);
}
