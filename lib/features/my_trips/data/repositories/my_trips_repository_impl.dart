import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/trip.dart';
import '../../domain/repositories/my_trips_repository.dart';
import '../datasources/my_trips_mock_datasource.dart';

class MyTripsRepositoryImpl implements MyTripsRepository {
  MyTripsRepositoryImpl(this._mock);
  final MyTripsMockDatasource _mock;

  @override
  Future<Either<Failure, List<Trip>>> getTrips(MyTripsTab tab) async {
    try {
      return right(await _mock.trips(tab));
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
