import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/home_repository.dart';

class GetPlaceLocation {
  const GetPlaceLocation(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, (double, double)>> call(
    String placeId, {
    String? sessionToken,
  }) => _repository.getPlaceLocation(placeId, sessionToken: sessionToken);
}
