import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/recent_place.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_mock_datasource.dart';
import '../datasources/maps_link_remote_datasource.dart';
import '../datasources/places_remote_datasource.dart';
import '../datasources/recent_places_local_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._mock, this._places, this._links, this._recent);

  final HomeMockDatasource _mock;
  final PlacesRemoteDatasource _places;
  final MapsLinkRemoteDatasource _links;
  final RecentPlacesLocalDatasource _recent;

  @override
  Future<Either<Failure, List<Trip>>> getNearbyTrips() => _guard(_mock.trips);

  @override
  Future<Either<Failure, List<MapPlace>>> getMapPlaces() =>
      _guard(_mock.places);

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> searchPlaces(
    String query, {
    String? sessionToken,
    double? latitude,
    double? longitude,
  }) => _guard(
    () => _places.autocomplete(
      query,
      sessionToken: sessionToken,
      latitude: latitude,
      longitude: longitude,
    ),
  );

  @override
  Future<Either<Failure, (double, double)>> getPlaceLocation(
    String placeId, {
    String? sessionToken,
  }) => _guard(() => _places.location(placeId, sessionToken: sessionToken));

  @override
  Future<Either<Failure, String>> resolveMapsLink(String url) =>
      _guard(() => _links.resolve(url));

  @override
  List<RecentPlace> getRecentPlaces() => _recent.read();

  @override
  Future<void> saveRecentPlace(RecentPlace place) => _recent.save(place);

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
