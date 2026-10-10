import '../../domain/entities/app_notification.dart';

/// Sample data. Replace with a remote datasource when the backend exists.
class NotificationsMockDatasource {
  static const _u = 'https://images.unsplash.com/';
  static const _a1 = '${_u}photo-1507003211169-0a1dd7228f2d?w=100';
  static const _a2 = '${_u}photo-1494790108377-be9c29b29330?w=100';

  Future<List<AppNotification>> notifications() async {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n1',
        type: NotificationType.like,
        actorName: 'Sneha',
        actorAvatarUrl: _a2,
        message: 'liked your trip Athirappilly Day Trip',
        createdAt: now.subtract(const Duration(minutes: 12)),
        tripId: 't2',
      ),
      AppNotification(
        id: 'n2',
        type: NotificationType.follow,
        actorName: 'Arjun',
        actorAvatarUrl: _a1,
        message: 'started following you',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n3',
        type: NotificationType.comment,
        actorName: 'Rohit',
        actorAvatarUrl: _a1,
        message: 'commented on Kochi to Munnar: "Great route!"',
        createdAt: now.subtract(const Duration(hours: 5)),
        tripId: 't1',
      ),
      AppNotification(
        id: 'n4',
        type: NotificationType.save,
        actorName: 'Neha',
        actorAvatarUrl: _a2,
        message: 'saved your trip Kozhikode Food Trail',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        tripId: 't4',
        isRead: true,
      ),
      AppNotification(
        id: 'n5',
        type: NotificationType.like,
        actorName: 'Arjun',
        actorAvatarUrl: _a1,
        message: 'liked your trip Wayanad Weekend',
        createdAt: now.subtract(const Duration(days: 3)),
        tripId: 't3',
        isRead: true,
      ),
    ];
  }
}
