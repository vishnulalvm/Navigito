import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../home/data/datasources/trip_social_remote_datasource.dart';
import '../../domain/entities/trip_comment.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../datasources/trip_comments_remote_datasource.dart';
import '../datasources/trip_detail_remote_datasource.dart';

class TripDetailRepositoryImpl implements TripDetailRepository {
  TripDetailRepositoryImpl(this._remote, this._social, this._comments);
  final TripDetailRemoteDatasource _remote;
  final TripSocialRemoteDatasource _social;
  final TripCommentsRemoteDatasource _comments;

  @override
  Future<Either<Failure, TripDetail>> getTripDetail(String id) =>
      _guard(() => _remote.detail(id));

  @override
  Future<Either<Failure, Unit>> setLiked(String tripId, bool liked) =>
      _guard(() async {
        await _social.setLiked(tripId, liked);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setSaved(String tripId, bool saved) =>
      _guard(() async {
        await _social.setSaved(tripId, saved);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setFollowing(String authorId, bool following) =>
      _guard(() async {
        await _social.setFollowing(authorId, following);
        return unit;
      });

  @override
  Future<Either<Failure, List<TripComment>>> getComments(
    String tripId, {
    DateTime? before,
  }) => _guard(() => _comments.page(tripId, before: before));

  @override
  Future<Either<Failure, TripComment>> addComment(String tripId, String body) =>
      _guard(() => _comments.add(tripId, body));

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) =>
      _guard(() async {
        await _comments.delete(commentId);
        return unit;
      });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return right(await run());
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
