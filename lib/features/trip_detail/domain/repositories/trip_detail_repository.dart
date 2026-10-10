import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/trip_detail.dart';

abstract interface class TripDetailRepository {
  Future<Either<Failure, TripDetail>> getTripDetail(String id);

  Future<Either<Failure, Unit>> setLiked(String tripId, bool liked);
  Future<Either<Failure, Unit>> setSaved(String tripId, bool saved);
  Future<Either<Failure, Unit>> setFollowing(String authorId, bool following);
}
