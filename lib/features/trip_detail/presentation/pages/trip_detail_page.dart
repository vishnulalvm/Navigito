import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/trip_detail.dart';
import '../providers/trip_detail_providers.dart';
import '../widgets/overview_tab.dart';
import '../widgets/photos_tab.dart';
import '../widgets/route_tab.dart';
import '../widgets/stops_tab.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BackButton(onPressed: context.pop),
              ),
              const Expanded(child: Center(child: Text('Could not load trip'))),
            ],
          ),
        ),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(TripDetail trip) {
    final overview = _tabs.index == 0;
    final notifier = ref.read(tripDetailProvider(trip.id).notifier);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: overview
              ? _FullHeader(
                  trip: trip,
                  onFollow: notifier.toggleFollow,
                  onLike: notifier.toggleLike,
                )
              : _CompactHeader(trip: trip, onLike: notifier.toggleLike),
        ),
        TabBar(
          controller: _tabs,
          dividerHeight: 1,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Route'),
            Tab(text: 'Stops'),
            Tab(text: 'Photos'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            // Prevent horizontal swipes from fighting with map gestures.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              OverviewTab(trip: trip),
              RouteTab(trip: trip),
              StopsTab(trip: trip),
              PhotosTab(trip: trip),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.trip, required this.onLike});
  final TripDetail trip;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 4),
            BackButton(onPressed: context.pop),
            Expanded(
              child: Text(
                trip.title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: onLike,
              icon: Icon(
                trip.isLiked ? Icons.favorite : Icons.favorite_border,
                color: trip.isLiked ? Colors.pinkAccent : null,
              ),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
          ],
        ),
      ),
    );
  }
}

class _FullHeader extends StatelessWidget {
  const _FullHeader({
    required this.trip,
    required this.onFollow,
    required this.onLike,
  });
  final TripDetail trip;
  final VoidCallback onFollow;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget stat(IconData icon, String text) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: theme.textTheme.titleSmall),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                trip.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: scheme.surfaceContainerHighest),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: IconTheme(
                      data: const IconThemeData(color: Colors.white),
                      child: Row(
                        children: [
                          BackButton(
                            color: Colors.white,
                            onPressed: context.pop,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: onLike,
                            icon: Icon(
                              trip.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: trip.isLiked
                                  ? Colors.pinkAccent
                                  : Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.ios_share),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            trip.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(trip.authorAvatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'by ${trip.authorName}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              trip.isFollowing
                  ? OutlinedButton(
                      onPressed: onFollow,
                      child: const Text('Following'),
                    )
                  : FilledButton(
                      onPressed: onFollow,
                      child: const Text('Follow'),
                    ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              stat(
                Icons.schedule,
                '${trip.days} ${trip.days == 1 ? 'Day' : 'Days'}',
              ),
              stat(Icons.place_outlined, '${trip.stopCount} Stops'),
              stat(Icons.route_outlined, '${trip.distanceKm} km'),
            ],
          ),
        ),
      ],
    );
  }
}
