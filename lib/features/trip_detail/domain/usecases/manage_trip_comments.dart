import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/trip_comment.dart';
import '../repositories/trip_detail_repository.dart';

/// Reading, posting and removing a trip's comments.
class ManageTripComments {
  const ManageTripComments(this._repository);
  final TripDetailRepository _repository;

  Future<Either<Failure, List<TripComment>>> page(
    String tripId, {
    DateTime? before,
  }) => _repository.getComments(tripId, before: before);

  /// Trims [body]; refuses it when blank or over 1000 characters.
  Future<Either<Failure, TripComment>> add(String tripId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return left(const ServerFailure('Write something first'));
    if (text.length > maxLength) {
      return left(const ServerFailure('Comments can be up to 1000 characters'));
    }
    return _repository.addComment(tripId, text);
  }

  Future<Either<Failure, Unit>> delete(String commentId) =>
      _repository.deleteComment(commentId);

  static const maxLength = 1000;
}
