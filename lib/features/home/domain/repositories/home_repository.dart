import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_place.dart';
import '../entities/place_info.dart';
import '../entities/place_suggestion.dart';
import '../entities/recent_place.dart';
import '../entities/trip.dart';

abstract interface class HomeRepository {
  /// Public trips, nearest to [latitude]/[longitude] first when given; with
  /// [withinMeters], only trips passing that close.
  Future<Either<Failure, List<Trip>>> getNearbyTrips({
    double? latitude,
    double? longitude,
    int? withinMeters,
  });

  /// Saves (favourites) or unsaves a trip for the signed-in user.
  Future<Either<Failure, Unit>> setTripSaved(String tripId, bool saved);
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

  /// Name, position and kind of a place, e.g. one tapped on the map.
  Future<Either<Failure, PlaceInfo>> getPlaceInfo(String placeId);

  /// Expands a Google Maps short link to the full URL it points to.
  Future<Either<Failure, String>> resolveMapsLink(String url);

  /// Places picked before, newest first.
  List<RecentPlace> getRecentPlaces();
  Future<void> saveRecentPlace(RecentPlace place);
}
