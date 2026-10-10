import 'package:equatable/equatable.dart';

enum NotificationType { like, comment, follow, save }

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.message,
    required this.createdAt,
    this.tripId,
    this.isRead = false,
  });

  final String id;
  final NotificationType type;
  final String actorName;
  final String actorAvatarUrl;

  /// Text shown after the actor name, e.g. "liked your trip Kochi to Munnar".
  final String message;
  final DateTime createdAt;
  final String? tripId;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    actorName: actorName,
    actorAvatarUrl: actorAvatarUrl,
    message: message,
    createdAt: createdAt,
    tripId: tripId,
    isRead: isRead ?? this.isRead,
  );

  @override
  List<Object?> get props => [id, isRead];
}
