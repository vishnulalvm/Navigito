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
        onClearPlace: () =>
            ref.read(searchedPlaceProvider.notifier).state = null,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _FilterChips(
              selected: filter,
              onSelected: (f) =>
                  ref.read(tripFilterProvider.notifier).state = f,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _ShareTripCard(onTap: _addTrip),
          ),
        ),
        trips.when(
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyState())
              : SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomInset),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList.separated(
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const TripCardSkeleton(),
            ),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: _Message(
              icon: Icons.cloud_off_outlined,
              text: 'Could not load trips',
              action: TextButton(
                onPressed: () => ref.invalidate(tripsProvider),
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addTrip() async {
    final ok = await ensureSignedIn(
      context,
      ref,
      reason: 'Sign in to share your trip',
    );
    if (ok && mounted) context.push(AppRouter.addTrip);
  }

  Widget _buildCard(Trip trip) => TripCard(
    key: ValueKey(trip.id),
    trip: trip,
    onTap: () => context.push(AppRouter.tripDetail(trip.id)),
    onRoute: () => widget.onShowRoute(trip.id),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.place, required this.onClearPlace});

  final String? place;
  final VoidCallback onClearPlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = place == null
        ? 'Find your best destinations'
        : 'Trips in $place';

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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final TripFilter selected;
  final ValueChanged<TripFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: TripFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = TripFilter.values[i];
          return ChoiceChip(
            avatar: Icon(switch (f) {
              TripFilter.nearby => Icons.near_me_rounded,
              TripFilter.trending => Icons.local_fire_department_rounded,
              TripFilter.weekend => Icons.weekend_rounded,
              TripFilter.roadTrips => Icons.alt_route_rounded,
              TripFilter.saved => Icons.favorite_rounded,
            }, size: 18),
            label: Text(f.label),
            selected: f == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(f),
          );
        },
      ),
    );
  }
}

/// Promo banner inviting users to share a trip: headline on the left, a
/// landscape illustration fading in on the right.
class _ShareTripCard extends StatelessWidget {
  const _ShareTripCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headline = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: scheme.onSurface,
    );

    return Material(
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.04),
        scheme.surfaceContainerLowest,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Illustration bleeds off the right edge; its left side fades
            // into the card so the text never sits on busy artwork.
            Positioned(
              top: 0,
              bottom: 0,
              right: -24,
              width: 230,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, 0.35],
                ).createShader(rect),
                child: Image.asset(
                  'assets/images/share_trip_illustration.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
              child: FractionallySizedBox(
                widthFactor: 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Find your next', style: headline),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (rect) => LinearGradient(
                              colors: [scheme.primary, scheme.tertiary],
                            ).createShader(rect),
                            child: Text(
                              'adventure',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: headline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        CustomPaint(
                          size: const Size(14, 14),
                          painter: _SparklePainter(color: scheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover amazing places, plan trips and share your '
                      'travel stories',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tells people the banner is tappable.
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: scheme.onPrimary),
                          const SizedBox(width: 4),
                          Text(
                            'Share a trip',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: scheme.onPrimary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three short rays beside "adventure", like a little burst of excitement.
class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas
      ..drawLine(Offset(w * 0.15, h * 0.55), Offset(w * 0.15, h * 0.95), paint)
      ..drawLine(Offset(w * 0.45, h * 0.45), Offset(w * 0.85, h * 0.1), paint)
      ..drawLine(Offset(w * 0.55, h * 0.8), Offset(w * 0.95, h * 0.75), paint);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
