import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../home/data/datasources/trip_social_remote_datasource.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../datasources/trip_detail_remote_datasource.dart';

class TripDetailRepositoryImpl implements TripDetailRepository {
  TripDetailRepositoryImpl(this._remote, this._social);
  final TripDetailRemoteDatasource _remote;
  final TripSocialRemoteDatasource _social;

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
