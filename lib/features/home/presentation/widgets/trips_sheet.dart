import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/map_sheet.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../../domain/entities/trip.dart';
import '../providers/home_providers.dart';
import 'trip_card.dart';

/// How many cards play the staggered entrance; later ones are off-screen.
const int _staggeredCards = 6;

/// Bottom sheet that starts at the very bottom of the screen (behind the
/// floating navbar). Trips are a vertical list that scrolls once the sheet is
/// fully expanded.
class TripsSheet extends ConsumerStatefulWidget {
  const TripsSheet({
    super.key,
    required this.controller,
    required this.bottomInset,
    required this.onShowRoute,
  });

  final MapSheetController controller;

  /// Extra list padding so the last card clears the floating navbar.
  final double bottomInset;

  /// Called when a card's Route button is pressed.
  final ValueChanged<String> onShowRoute;

  @override
  ConsumerState<TripsSheet> createState() => _TripsSheetState();
}

class _TripsSheetState extends ConsumerState<TripsSheet>
    with SingleTickerProviderStateMixin {
  /// Drives the staggered card entrance. It replays only when the set of
  /// trips changes (load, filter, place), not when a trip is liked.
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (ref.read(filteredTripsProvider).hasValue) _entrance.value = 1;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  static List<String>? _ids(AsyncValue<List<Trip>>? trips) =>
      trips?.valueOrNull?.map((t) => t.id).toList();

  @override
  Widget build(BuildContext context) {
    ref.listen(filteredTripsProvider, (prev, next) {
      final ids = _ids(next);
      if (ids != null && !listEquals(_ids(prev), ids)) {
        _entrance.forward(from: 0);
      }
    });
    final trips = ref.watch(filteredTripsProvider);
    final filter = ref.watch(tripFilterProvider);
    final place = ref.watch(searchedPlaceProvider);

    return MapSheet(
      controller: widget.controller,
      header: _HeaderRow(
        place: place,
        filter: filter,
        onClearPlace: () =>
            ref.read(searchedPlaceProvider.notifier).state = null,
        onFilter: (f) => ref.read(tripFilterProvider.notifier).state = f,
      ),
      slivers: [
        trips.when(
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyState())
              : SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, widget.bottomInset),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _Entrance(
                      animation: _entrance,
                      index: i,
                      child: _buildCard(items[i]),
                    ),
                  ),
                ),
          loading: () => SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.separated(
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const TripCardSkeleton(),
            ),
          ),
          error: (_, _) => const SliverToBoxAdapter(
            child: _Message(
              icon: Icons.cloud_off_outlined,
              text: 'Could not load trips',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Trip trip) => TripCard(
    key: ValueKey(trip.id),
    trip: trip,
    onTap: () => context.push(AppRouter.tripDetail(trip.id)),
    onRoute: () => widget.onShowRoute(trip.id),
    onFavorite: () async {
      final ok = await ensureSignedIn(
        context,
        ref,
        reason: 'Sign in to like trips',
      );
      if (ok) ref.read(tripsProvider.notifier).toggleFavorite(trip.id);
    },
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.place,
    required this.filter,
    required this.onClearPlace,
    required this.onFilter,
  });

  final String? place;
  final TripFilter filter;
  final VoidCallback onClearPlace;
  final ValueChanged<TripFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = place == null ? 'Public trips near you' : 'Trips in $place';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                title,
                key: ValueKey(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: place == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear place',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClearPlace,
                    icon: const Icon(Icons.close),
                  ),
          ),
          _FilterDropdown(selected: filter, onSelected: onFilter),
        ],
      ),
    );
  }
}

/// Fades and lifts a card in, each a beat after the one above.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= _staggeredCards) return child;
    final start = index * 0.08;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(tripFilterProvider) != TripFilter.nearby;
    return _Message(
      icon: Icons.travel_explore,
      text: 'No trips match this filter',
      action: filtered
          ? TextButton(
              onPressed: () => ref.read(tripFilterProvider.notifier).state =
                  TripFilter.nearby,
              child: const Text('Show all trips'),
            )
          : null,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          ?action,
        ],
      ),
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
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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
      ),
    );
  }
}
