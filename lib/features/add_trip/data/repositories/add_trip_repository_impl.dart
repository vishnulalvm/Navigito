import 'dart:typed_data';

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
  Future<Either<Failure, String>> createTrip(NewTrip trip) =>
      _guard(() => _remote.create(trip));

  @override
  Future<Either<Failure, String>> uploadStopPhoto(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) => _guard(() => _remote.uploadPhoto(bytes, contentType: contentType));

  @override
  Future<Either<Failure, Unit>> deleteStopPhoto(String url) => _guard(() async {
    await _remote.deletePhoto(url);
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
