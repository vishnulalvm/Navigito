import 'package:equatable/equatable.dart';

import 'trip_stop.dart';

class TripDetail extends Equatable {
  const TripDetail({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.tags,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.days,
    required this.distanceKm,
    required this.likes,
    required this.comments,
    required this.startDate,
    required this.stops,
    this.isLiked = false,
    this.isFollowing = false,
    this.isSaved = false,
  });

  final String id;
  final String title;
  final String coverUrl;
  final String description;
  final List<String> tags;

  /// Profile id of the author, for following them.
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final int days;
  final int distanceKm;
  final int likes;
  final int comments;
  final DateTime startDate;
  final List<TripStop> stops;
  final bool isLiked;
  final bool isFollowing;
  final bool isSaved;

  int get stopCount => stops.length;

  TripDetail copyWith({
    bool? isLiked,
    bool? isFollowing,
    bool? isSaved,
    int? likes,
  }) => TripDetail(
    id: id,
    title: title,
    coverUrl: coverUrl,
    description: description,
    tags: tags,
    authorId: authorId,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    days: days,
    distanceKm: distanceKm,
    likes: likes ?? this.likes,
    comments: comments,
    startDate: startDate,
    stops: stops,
    isLiked: isLiked ?? this.isLiked,
    isFollowing: isFollowing ?? this.isFollowing,
    isSaved: isSaved ?? this.isSaved,
  );

  @override
  List<Object?> get props => [id, likes, isLiked, isFollowing, isSaved];
}
