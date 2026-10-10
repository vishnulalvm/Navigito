import '../../domain/entities/trip_detail.dart';
import '../../domain/entities/trip_stop.dart';

/// The JSON document returned by the `trip_detail` function.
TripDetail tripDetailFromJson(Map<String, dynamic> json) {
  final author = json['author'] as Map<String, dynamic>? ?? const {};
  return TripDetail(
    id: json['id'] as String,
    title: json['title'] as String,
    coverUrl: json['cover_url'] as String? ?? '',
    description: json['description'] as String? ?? '',
    tags: [...?(json['tags'] as List?)?.cast<String>()],
    authorId: author['id'] as String? ?? '',
    authorName: author['name'] as String? ?? 'Traveller',
    authorAvatarUrl: author['avatar_url'] as String? ?? '',
    days: json['days'] as int,
    distanceKm: json['distance_km'] as int? ?? 0,
    likes: json['likes_count'] as int? ?? 0,
    comments: json['comments_count'] as int? ?? 0,
    startDate: DateTime.parse(json['start_date'] as String),
    isLiked: json['is_liked'] == true,
    isSaved: json['is_saved'] == true,
    isFollowing: json['is_following'] == true,
    stops: [
      for (final s in (json['stops'] as List? ?? const []))
        _stop(s as Map<String, dynamic>),
    ],
  );
}

TripStop _stop(Map<String, dynamic> s) => TripStop(
  id: s['id'] as String,
  day: s['day'] as int,
  time: s['time'] as String? ?? '',
  title: s['title'] as String,
  subtitle: s['subtitle'] as String?,
  type: StopType.values.asNameMap()[s['type']] ?? StopType.attraction,
  latitude: (s['latitude'] as num).toDouble(),
  longitude: (s['longitude'] as num).toDouble(),
  photoUrls: [...?(s['photo_urls'] as List?)?.cast<String>()],
  placeId: s['place_id'] as String?,
  travelMinutes: s['travel_minutes'] as int?,
  distanceKm: s['distance_km'] as int?,
);
