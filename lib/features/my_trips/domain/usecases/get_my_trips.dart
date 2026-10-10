import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/trip.dart';
import '../repositories/my_trips_repository.dart';

class GetMyTrips {
  const GetMyTrips(this._repository);
  final MyTripsRepository _repository;

  Future<Either<Failure, List<Trip>>> call(MyTripsTab tab) =>
      _repository.getTrips(tab);
}
