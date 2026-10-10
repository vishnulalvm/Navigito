import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/my_trips_repository.dart';

class DeleteTrip {
  const DeleteTrip(this._repository);
  final MyTripsRepository _repository;

  Future<Either<Failure, Unit>> call(String tripId) =>
      _repository.deleteTrip(tripId);
}
