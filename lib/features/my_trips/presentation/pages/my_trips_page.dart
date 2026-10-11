import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/snackbar.dart';
import '../widgets/confirm_delete_trip.dart';
import '../../../../core/router/app_router.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../../domain/repositories/my_trips_repository.dart';
import '../providers/my_trips_providers.dart';
import '../widgets/my_trip_tile.dart';
import '../widgets/my_trips_segmented_tabs.dart';

class MyTripsPage extends ConsumerWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(myTripsTabProvider);
    final trips = ref.watch(myTripsProvider(tab));
    final notifier = ref.read(myTripsProvider(tab).notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Trips',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MyTripsSegmentedTabs(
                selected: tab,
                onChanged: (t) =>
                    ref.read(myTripsTabProvider.notifier).state = t,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: trips.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load trips'),
                      TextButton(
                        onPressed: () => ref.invalidate(myTripsProvider(tab)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) => items.isEmpty
                    ? Center(
                        child: Text(switch (tab) {
                          MyTripsTab.saved => 'No saved trips yet',
                          MyTripsTab.mine => 'You have not created any trips',
                          MyTripsTab.liked => 'No liked trips yet',
                        }, style: TextStyle(color: scheme.onSurfaceVariant)),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          FloatingNavBar.reservedSpace(context) + 8,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => MyTripTile(
                          trip: items[i],
                          onTap: () =>
                              context.push(AppRouter.tripDetail(items[i].id)),
                          onFavorite: () async {
                            final error = await notifier.toggleFavorite(
                              items[i].id,
                            );
                            if (context.mounted) showErrorSnack(context, error);
                          },
                          removeLabel: tab == MyTripsTab.mine
                              ? 'Delete'
                              : 'Remove',
                          onRemove: () async {
                            if (tab == MyTripsTab.mine &&
                                !await confirmDeleteTrip(
                                  context,
                                  items[i].title,
                                )) {
                              return;
                            }
                            final error = await notifier.remove(items[i].id);
                            if (context.mounted) {
                              showErrorSnack(context, error);
                            }
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
