import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/new_trip.dart';
import '../../domain/repositories/add_trip_repository.dart';
import '../datasources/add_trip_remote_datasource.dart';

class AddTripRepositoryImpl implements AddTripRepository {
  AddTripRepositoryImpl(this._remote);
  final AddTripRemoteDatasource _remote;

  @override
  Future<Either<Failure, String>> createTrip(NewTrip trip) async {
    try {
      return right(await _remote.create(trip));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
