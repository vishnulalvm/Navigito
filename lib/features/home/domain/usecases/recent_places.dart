import '../entities/recent_place.dart';
import '../repositories/home_repository.dart';

class GetRecentPlaces {
  const GetRecentPlaces(this._repository);
  final HomeRepository _repository;

  List<RecentPlace> call() => _repository.getRecentPlaces();
}

class SaveRecentPlace {
  const SaveRecentPlace(this._repository);
  final HomeRepository _repository;

  Future<void> call(RecentPlace place) => _repository.saveRecentPlace(place);
}
