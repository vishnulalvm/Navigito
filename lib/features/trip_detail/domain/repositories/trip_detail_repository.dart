import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/trip_comment.dart';
import '../entities/trip_detail.dart';

abstract interface class TripDetailRepository {
  Future<Either<Failure, TripDetail>> getTripDetail(String id);

  Future<Either<Failure, Unit>> setLiked(String tripId, bool liked);
  Future<Either<Failure, Unit>> setSaved(String tripId, bool saved);
  Future<Either<Failure, Unit>> setFollowing(String authorId, bool following);

  /// Newest first; pass the oldest loaded comment's time for the next page.
  Future<Either<Failure, List<TripComment>>> getComments(
    String tripId, {
    DateTime? before,
  });
  Future<Either<Failure, TripComment>> addComment(String tripId, String body);
  Future<Either<Failure, Unit>> deleteComment(String commentId);
}
