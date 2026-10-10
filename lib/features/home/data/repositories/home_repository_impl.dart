import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_mock_datasource.dart';
import '../datasources/places_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._mock, this._places);

  final HomeMockDatasource _mock;
  final PlacesRemoteDatasource _places;

  @override
  Future<Either<Failure, List<Trip>>> getNearbyTrips() => _guard(_mock.trips);

  @override
  Future<Either<Failure, List<MapPlace>>> getMapPlaces() =>
      _guard(_mock.places);

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> searchPlaces(String query) =>
      _guard(() => _places.autocomplete(query));

  @override
  Future<Either<Failure, (double, double)>> getPlaceLocation(String placeId) =>
      _guard(() => _places.location(placeId));

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
