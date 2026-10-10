import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/place_info.dart';
import '../repositories/home_repository.dart';

class GetPlaceInfo {
  const GetPlaceInfo(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, PlaceInfo>> call(String placeId) =>
      _repository.getPlaceInfo(placeId);
}
