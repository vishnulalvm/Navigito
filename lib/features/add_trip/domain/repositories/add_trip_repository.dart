import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/new_trip.dart';

abstract interface class AddTripRepository {
  /// Creates the trip with all its stops; returns the new trip's id.
  Future<Either<Failure, String>> createTrip(NewTrip trip);
}
