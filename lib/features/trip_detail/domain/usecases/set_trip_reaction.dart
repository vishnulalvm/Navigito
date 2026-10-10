import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/trip_detail_repository.dart';

/// Likes, saves and author follows from the trip screen.
class SetTripReaction {
  const SetTripReaction(this._repository);
  final TripDetailRepository _repository;

  Future<Either<Failure, Unit>> like(String tripId, bool on) =>
      _repository.setLiked(tripId, on);

  Future<Either<Failure, Unit>> save(String tripId, bool on) =>
      _repository.setSaved(tripId, on);

  Future<Either<Failure, Unit>> follow(String authorId, bool on) =>
      _repository.setFollowing(authorId, on);
}
