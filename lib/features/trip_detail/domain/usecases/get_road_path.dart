import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/route_repository.dart';

class GetRoadPath {
  const GetRoadPath(this._repository);
  final RouteRepository _repository;

  Future<Either<Failure, List<(double, double)>>> call(
    List<(double, double)> waypoints,
  ) => _repository.getRoadPath(waypoints);
}
