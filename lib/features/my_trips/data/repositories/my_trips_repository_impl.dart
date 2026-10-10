import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/trip.dart';
import '../../domain/repositories/my_trips_repository.dart';
import '../datasources/my_trips_remote_datasource.dart';

class MyTripsRepositoryImpl implements MyTripsRepository {
  MyTripsRepositoryImpl(this._remote);
  final MyTripsRemoteDatasource _remote;

  @override
  Future<Either<Failure, List<Trip>>> getTrips(MyTripsTab tab) =>
      _guard(() => _remote.trips(tab));

  @override
  Future<Either<Failure, Unit>> deleteTrip(String tripId) => _guard(() async {
    await _remote.delete(tripId);
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
