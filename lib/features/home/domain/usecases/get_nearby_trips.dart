import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/trip.dart';
import '../repositories/home_repository.dart';

class GetNearbyTrips {
  const GetNearbyTrips(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, List<Trip>>> call() => _repository.getNearbyTrips();
}
