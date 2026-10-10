import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/add_trip_repository.dart';

class UploadStopPhoto {
  const UploadStopPhoto(this._repository);
  final AddTripRepository _repository;

  Future<Either<Failure, String>> call(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) => _repository.uploadStopPhoto(bytes, contentType: contentType);
}

class DeleteStopPhoto {
  const DeleteStopPhoto(this._repository);
  final AddTripRepository _repository;

  Future<Either<Failure, Unit>> call(String url) =>
      _repository.deleteStopPhoto(url);
}
