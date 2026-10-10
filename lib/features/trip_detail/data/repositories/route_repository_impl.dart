import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/routes_remote_datasource.dart';

class RouteRepositoryImpl implements RouteRepository {
  RouteRepositoryImpl(this._remote);
  final RoutesRemoteDatasource _remote;

  @override
  Future<Either<Failure, List<(double, double)>>> getRoadPath(
    List<(double, double)> waypoints,
  ) async {
    try {
      return right(await _remote.roadPath(waypoints));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
