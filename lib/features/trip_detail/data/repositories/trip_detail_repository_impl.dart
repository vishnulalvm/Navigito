import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../datasources/trip_detail_mock_datasource.dart';

class TripDetailRepositoryImpl implements TripDetailRepository {
  TripDetailRepositoryImpl(this._mock);
  final TripDetailMockDatasource _mock;

  @override
  Future<Either<Failure, TripDetail>> getTripDetail(String id) async {
    try {
      return right(await _mock.detail(id));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
