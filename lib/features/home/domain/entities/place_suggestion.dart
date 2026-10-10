import 'package:equatable/equatable.dart';

class PlaceSuggestion extends Equatable {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    this.secondaryText = '',
    this.mainMatches = const [],
    this.distanceMeters,
    this.types = const [],
  });

  final String placeId;

  /// Place name, e.g. "Kovalam".
  final String mainText;

  /// Disambiguating context, e.g. "Thiruvananthapuram, Kerala".
  final String secondaryText;

  /// (start, end) ranges of [mainText] that match the typed query.
  final List<(int, int)> mainMatches;

  /// Straight-line distance from the user, when their location is known.
  final int? distanceMeters;

  /// Google place types, e.g. `restaurant`, `lodging`, `tourist_attraction`.
  final List<String> types;

  String get description =>
      secondaryText.isEmpty ? mainText : '$mainText, $secondaryText';

  @override
  List<Object?> get props => [placeId];
}
