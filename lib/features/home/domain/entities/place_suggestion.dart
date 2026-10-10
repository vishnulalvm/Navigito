import 'package:equatable/equatable.dart';

class PlaceSuggestion extends Equatable {
  const PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;

  @override
  List<Object?> get props => [placeId];
}
