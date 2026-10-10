import 'package:equatable/equatable.dart';

/// A Google place's name, position and kind, e.g. one tapped on the map.
class PlaceInfo extends Equatable {
  const PlaceInfo({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.types = const [],
  });

  final String placeId;
  final String name;
  final double latitude;
  final double longitude;

  /// Short address, e.g. "Fort Kochi, Kochi".
  final String address;

  /// Google place types, e.g. `restaurant`, `lodging`.
  final List<String> types;

  @override
  List<Object?> get props => [placeId];
}
