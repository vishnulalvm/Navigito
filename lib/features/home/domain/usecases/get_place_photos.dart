import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/place_photo.dart';
import '../repositories/home_repository.dart';

class GetPlacePhotos {
  const GetPlacePhotos(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, List<PlacePhoto>>> call(String placeId) =>
      _repository.getPlacePhotos(placeId);
}
