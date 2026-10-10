import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/new_trip.dart';

abstract interface class AddTripRepository {
  /// Creates the trip with all its stops; returns the new trip's id.
  Future<Either<Failure, String>> createTrip(NewTrip trip);

  /// Stores a photo of a stop for good; returns its public URL.
  Future<Either<Failure, String>> uploadStopPhoto(
    Uint8List bytes, {
    String contentType,
  });

  /// Removes a photo uploaded with [uploadStopPhoto].
  Future<Either<Failure, Unit>> deleteStopPhoto(String url);
}
