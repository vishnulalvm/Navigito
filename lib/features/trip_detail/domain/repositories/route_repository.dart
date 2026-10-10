import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

abstract interface class RouteRepository {
  /// Road path (latitude, longitude) through the ordered waypoints.
  Future<Either<Failure, List<(double, double)>>> getRoadPath(
    List<(double, double)> waypoints,
  );
}
