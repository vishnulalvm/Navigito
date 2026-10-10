import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_providers.dart';
import '../widgets/notification_tile.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final theme = Theme.of(context);
    final unread = async.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: unread == 0 ? null : notifier.markAllRead,
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Could not load notifications')),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        "You're all caught up",
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final now = DateTime.now();
                  final today = items
                      .where((n) => now.difference(n.createdAt).inHours < 24)
                      .toList();
                  final earlier = items
                      .where((n) => now.difference(n.createdAt).inHours >= 24)
                      .toList();

                  Widget section(String title, List<AppNotification> list) =>
                      SliverMainAxisGroup(
                        slivers: [
                          if (list.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
                                child: Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SliverList.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => NotificationTile(
                                notification: list[i],
                                onTap: () {
                                  notifier.markRead(list[i].id);
                                  final tripId = list[i].tripId;
                                  if (tripId != null) {
                                    context.push(AppRouter.tripDetail(tripId));
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      );

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          FloatingNavBar.reservedSpace(context) + 8,
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            section('Today', today),
                            section('Earlier', earlier),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
