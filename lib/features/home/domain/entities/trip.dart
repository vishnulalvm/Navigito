import 'package:equatable/equatable.dart';

class Trip extends Equatable {
  const Trip({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.days,
    required this.stops,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.likes,
    this.distanceKm = 0,
    this.places = const [],
    this.isFavorite = false,
    this.coverPlaceId,
    this.description = '',
    this.tags = const [],
    this.photosCount = 0,
  });

  final String id;
  final String title;

  /// Uploaded cover; empty when the trip has none.
  final String coverUrl;

  /// Google place of its first stop, for a live cover when [coverUrl] is
  /// empty.
  final String? coverPlaceId;
  final int days;
  final int stops;
  final String authorName;
  final String authorAvatarUrl;
  final int likes;
  final int distanceKm;

  /// Lowercase names of places the trip passes through (used for place search).
  final List<String> places;
  final bool isFavorite;
  final String description;

  /// Lowercase labels such as "cultural"; the first is shown as the category.
  final List<String> tags;

  /// Photos the author uploaded across all stops.
  final int photosCount;

  Trip copyWith({bool? isFavorite, int? likes}) => Trip(
    id: id,
    title: title,
    coverUrl: coverUrl,
    days: days,
    stops: stops,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    likes: likes ?? this.likes,
    distanceKm: distanceKm,
    places: places,
    isFavorite: isFavorite ?? this.isFavorite,
    coverPlaceId: coverPlaceId,
    description: description,
    tags: tags,
    photosCount: photosCount,
  );

  @override
  List<Object?> get props => [id, isFavorite, likes];
}
