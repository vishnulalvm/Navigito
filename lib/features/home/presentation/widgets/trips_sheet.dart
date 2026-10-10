import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../providers/home_providers.dart';
import 'trip_card.dart';

/// Height of the drag handle + title row, used to size the collapsed sheet.
const double kTripsSheetHeaderHeight = 84;

/// Bottom sheet that starts at the very bottom of the screen (behind the
/// floating navbar). Trips are a vertical list that scrolls once the sheet is
/// fully expanded.
class TripsSheet extends ConsumerWidget {
  const TripsSheet({
    super.key,
    required this.controller,
    required this.minSize,
    required this.initialSize,
    required this.maxSize,
    required this.bottomInset,
    required this.onShowRoute,
  });

  final DraggableScrollableController controller;
  final double minSize;
  final double initialSize;
  final double maxSize;

  /// Extra list padding so the last card clears the floating navbar.
  final double bottomInset;

  /// Called when a card's Route button is pressed.
  final ValueChanged<String> onShowRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final trips = ref.watch(filteredTripsProvider);
    final filter = ref.watch(tripFilterProvider);
    final place = ref.watch(searchedPlaceProvider);

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: [initialSize],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: kTripsSheetHeaderHeight,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    place == null
                                        ? 'Public trips near you'
                                        : 'Trips in $place',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (place != null)
                                  IconButton(
                                    tooltip: 'Clear place',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        ref
                                                .read(
                                                  searchedPlaceProvider
                                                      .notifier,
                                                )
                                                .state =
                                            null,
                                    icon: const Icon(Icons.close),
                                  ),
                                _FilterDropdown(
                                  selected: filter,
                                  onSelected: (f) =>
                                      ref
                                              .read(tripFilterProvider.notifier)
                                              .state =
                                          f,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                trips.when(
                  data: (items) => items.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('No trips match this filter'),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                          sliver: SliverList.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => TripCard(
                              trip: items[i],
                              onTap: () => context.push(
                                AppRouter.tripDetail(items[i].id),
                              ),
                              onView: () => context.push(
                                AppRouter.tripDetail(items[i].id),
                              ),
                              onRoute: () => onShowRoute(items[i].id),
                              onFavorite: () async {
                                final ok = await ensureSignedIn(
                                  context,
                                  ref,
                                  reason: 'Sign in to like trips',
                                );
                                if (ok) {
                                  ref
                                      .read(tripsProvider.notifier)
                                      .toggleFavorite(items[i].id);
                                }
                              },
                            ),
                          ),
                        ),
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Could not load trips')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.selected, required this.onSelected});

  final TripFilter selected;
  final ValueChanged<TripFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<TripFilter>(
      initialValue: selected,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final f in TripFilter.values)
          PopupMenuItem(
            value: f,
            child: Row(
              children: [
                Expanded(child: Text(f.label)),
                if (f == selected)
                  Icon(Icons.check, size: 18, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
