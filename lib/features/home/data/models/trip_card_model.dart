import '../../domain/entities/trip.dart';

/// A row of the `trip_cards` view (also returned by `feed_trips` and
/// `my_trips`).
Trip tripFromCard(Map<String, dynamic> row) => Trip(
  id: row['id'] as String,
  title: row['title'] as String,
  coverUrl: row['cover_url'] as String? ?? '',
  days: row['days'] as int,
  stops: row['stops_count'] as int? ?? 0,
  authorName: row['author_name'] as String? ?? 'Traveller',
  authorAvatarUrl: row['author_avatar_url'] as String? ?? '',
  likes: row['likes_count'] as int? ?? 0,
  distanceKm: row['distance_km'] as int? ?? 0,
  places: [...?(row['places'] as List?)?.cast<String>()],
  isFavorite: row['is_saved'] == true,
  coverPlaceId: row['cover_place_id'] as String?,
);

List<Trip> tripsFromCards(Object? rows) => [
  for (final r in (rows as List? ?? const []))
    tripFromCard(r as Map<String, dynamic>),
];
