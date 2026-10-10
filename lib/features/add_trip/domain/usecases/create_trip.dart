import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/new_trip.dart';
import '../repositories/add_trip_repository.dart';

class CreateTrip {
  const CreateTrip(this._repository);
  final AddTripRepository _repository;

  Future<Either<Failure, String>> call(NewTrip trip) =>
      _repository.createTrip(trip);
}
