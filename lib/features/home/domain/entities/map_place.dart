import 'package:equatable/equatable.dart';

class MapPlace extends Equatable {
  const MapPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.photoUrl,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String photoUrl;

  @override
  List<Object?> get props => [id];
}
