import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/place_suggestion.dart';
import '../repositories/home_repository.dart';

class SearchPlaces {
  const SearchPlaces(this._repository);
  final HomeRepository _repository;

  Future<Either<Failure, List<PlaceSuggestion>>> call(String query) =>
      _repository.searchPlaces(query);
}
