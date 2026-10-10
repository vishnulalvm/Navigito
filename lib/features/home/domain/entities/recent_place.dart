import 'package:equatable/equatable.dart';

/// A place the user picked before. Kept on the device so picking it again
/// needs no Places API call.
class RecentPlace extends Equatable {
  const RecentPlace({
    required this.placeId,
    required this.name,
    required this.secondaryText,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  final String placeId;
  final String name;
  final String secondaryText;
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  Map<String, Object> toJson() => {
    'placeId': placeId,
    'name': name,
    'secondaryText': secondaryText,
    'latitude': latitude,
    'longitude': longitude,
    'savedAt': savedAt.toIso8601String(),
  };

  factory RecentPlace.fromJson(Map<String, dynamic> json) => RecentPlace(
    placeId: json['placeId'] as String,
    name: json['name'] as String,
    secondaryText: json['secondaryText'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    savedAt: DateTime.parse(json['savedAt'] as String),
  );

  @override
  List<Object?> get props => [placeId];
}
