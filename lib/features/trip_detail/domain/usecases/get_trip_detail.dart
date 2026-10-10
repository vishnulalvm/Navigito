import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/trip_detail.dart';
import '../repositories/trip_detail_repository.dart';

class GetTripDetail {
  const GetTripDetail(this._repository);
  final TripDetailRepository _repository;

  Future<Either<Failure, TripDetail>> call(String id) =>
      _repository.getTripDetail(id);
}
