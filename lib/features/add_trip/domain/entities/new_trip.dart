import '../../../trip_detail/domain/entities/trip_stop.dart';

/// A trip as the user built it, ready to be created.
class NewTrip {
  const NewTrip({
    required this.title,
    required this.days,
    required this.stops,
    this.description = '',
    this.tags = const [],
    this.isPublic = true,
  });

  final String title;
  final String description;
  final int days;
  final List<String> tags;
  final bool isPublic;

  /// In visiting order.
  final List<NewStop> stops;
}

class NewStop {
  const NewStop({
    required this.day,
    required this.time,
    required this.title,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.subtitle = '',
    this.placeId,
    this.photoUrls = const [],
  });

  final int day;

  /// 24h "HH:mm".
  final String time;
  final String title;
  final String subtitle;
  final StopType type;
  final double latitude;
  final double longitude;

  /// Google place id, when the stop came from Google.
  final String? placeId;

  /// Up to 3 photos the user uploaded.
  final List<String> photoUrls;
}
