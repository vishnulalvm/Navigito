import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/trip_detail.dart';

abstract interface class TripDetailRepository {
  Future<Either<Failure, TripDetail>> getTripDetail(String id);
}
