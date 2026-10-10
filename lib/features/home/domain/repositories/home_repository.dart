import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_place.dart';
import '../entities/place_suggestion.dart';
import '../entities/recent_place.dart';
import '../entities/trip.dart';

abstract interface class HomeRepository {
  Future<Either<Failure, List<Trip>>> getNearbyTrips();
  Future<Either<Failure, List<MapPlace>>> getMapPlaces();

  /// Pass the same [sessionToken] to every search of one session and to the
  /// final [getPlaceLocation]; Google then bills the session, not each request.
  /// [latitude]/[longitude] bias results towards the user.
  Future<Either<Failure, List<PlaceSuggestion>>> searchPlaces(
    String query, {
    String? sessionToken,
    double? latitude,
    double? longitude,
  });

  /// Returns (latitude, longitude) of a place.
  Future<Either<Failure, (double, double)>> getPlaceLocation(
    String placeId, {
    String? sessionToken,
  });

  /// Places picked before, newest first.
  List<RecentPlace> getRecentPlaces();
  Future<void> saveRecentPlace(RecentPlace place);
}
