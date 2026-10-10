import 'package:equatable/equatable.dart';

enum StopType { start, food, attraction, stay }

class TripStop extends Equatable {
  const TripStop({
    required this.id,
    required this.day,
    required this.time,
    required this.title,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.photoUrl,
    this.subtitle,
    this.travelMinutes,
    this.distanceKm,
  });

  final String id;
  final int day;

  /// 24h "HH:mm".
  final String time;
  final String title;
  final String? subtitle;
  final StopType type;
  final double latitude;
  final double longitude;
  final String photoUrl;

  /// Travel from the previous stop.
  final int? travelMinutes;
  final int? distanceKm;

  @override
  List<Object?> get props => [id];
}
