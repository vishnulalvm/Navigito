import 'package:equatable/equatable.dart';

class TripComment extends Equatable {
  const TripComment({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.body,
    required this.createdAt,
    required this.authorName,
    required this.authorAvatarUrl,
  });

  final String id;
  final String tripId;

  /// Profile id of whoever wrote it.
  final String userId;
  final String body;
  final DateTime createdAt;
  final String authorName;
  final String authorAvatarUrl;

  @override
  List<Object?> get props => [id];
}
