import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_place.dart';
import '../repositories/home_repository.dart';

class GetMapPlaces {
  const GetMapPlaces(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, List<MapPlace>>> call() => _repository.getMapPlaces();
}
