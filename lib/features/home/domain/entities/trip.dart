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
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String coverUrl;
  final int days;
  final int stops;
  final String authorName;
  final String authorAvatarUrl;
  final int likes;
  final int distanceKm;
  final bool isFavorite;

  Trip copyWith({bool? isFavorite}) => Trip(
    id: id,
    title: title,
    coverUrl: coverUrl,
    days: days,
    stops: stops,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    likes: likes,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  @override
  List<Object?> get props => [id, isFavorite];
}
