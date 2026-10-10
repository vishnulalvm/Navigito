import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/get_notifications.dart';

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final result = await GetNotifications(sl<NotificationsRepository>())();
    return result.getOrElse((_) => const []);
  }

  void markRead(String id) =>
      _map((n) => n.id == id ? n.copyWith(isRead: true) : n);

  void markAllRead() => _map((n) => n.copyWith(isRead: true));

  void _map(AppNotification Function(AppNotification) fn) {
    final items = state.valueOrNull;
    if (items != null) state = AsyncData(items.map(fn).toList());
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );
