import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_place.dart';
import '../entities/place_suggestion.dart';
import '../entities/trip.dart';

abstract interface class HomeRepository {
  Future<Either<Failure, List<Trip>>> getNearbyTrips();
  Future<Either<Failure, List<MapPlace>>> getMapPlaces();
  Future<Either<Failure, List<PlaceSuggestion>>> searchPlaces(String query);

  /// Returns (latitude, longitude) of a place.
  Future<Either<Failure, (double, double)>> getPlaceLocation(String placeId);
}
