import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/trip.dart';

enum MyTripsTab { saved, mine, liked }

abstract interface class MyTripsRepository {
  Future<Either<Failure, List<Trip>>> getTrips(MyTripsTab tab);

  /// Deletes one of the signed-in user's own trips.
  Future<Either<Failure, Unit>> deleteTrip(String tripId);
}
