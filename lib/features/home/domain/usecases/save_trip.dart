import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/home_repository.dart';

/// Saves (favourites) or unsaves a trip for the signed-in user.
class SaveTrip {
  const SaveTrip(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, Unit>> call(String tripId, bool saved) =>
      _repository.setTripSaved(tripId, saved);
}
