import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../../../home/presentation/widgets/place_photos.dart';
import '../../domain/entities/trip_detail.dart';
import '../providers/trip_detail_providers.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/overview_tab.dart';
import '../widgets/photos_tab.dart';
import '../widgets/route_tab.dart';
import '../widgets/stops_tab.dart';
import '../widgets/trip_share.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this)
    ..addListener(_onTabChanged);

  /// Tabs visited before the current one, so back retraces them.
  final _tabHistory = <int>[];
  int _shownTab = 0;
  bool _goingBack = false;

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _tabs.index == _shownTab) return;
    if (!_goingBack) {
      // Revisiting a tab moves it to the top instead of stacking a loop.
      _tabHistory
        ..remove(_tabs.index)
        ..add(_shownTab);
    }
    _goingBack = false;
    setState(() => _shownTab = _tabs.index);
  }

  /// System back: steps to the previous tab first, then leaves the page.
  void _onBack() {
    if (_tabHistory.isNotEmpty) {
      _goingBack = true;
      _tabs.animateTo(_tabHistory.removeLast());
    } else {
      _leave();
    }
  }

  /// Back to wherever the trip was opened from; home when it was opened by
  /// a link and there is nothing underneath.
  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRouter.home);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripDetailProvider(widget.tripId));

    return PopScope(
      canPop: _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackButton(onPressed: _leave),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load trip'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              ref.invalidate(tripDetailProvider(widget.tripId)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  /// Runs [action] once signed in; tells the user if it didn't stick.
  Future<void> _guarded(
    String reason,
    Future<String?> Function() action,
  ) async {
    if (!await ensureSignedIn(context, ref, reason: reason)) return;
    final error = await action();
    if (mounted) showErrorSnack(context, error);
  }

  Future<void> _confirmDelete(TripDetail trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text(
          '"${trip.title}" and its likes, saves and comments will be '
          'removed for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await ref.read(tripDetailProvider(trip.id).notifier).delete();
    if (!mounted) return;
    if (error != null) return showErrorSnack(context, error);
    showErrorSnack(context, 'Trip deleted');
    _leave();
  }

  Future<void> _showMore(TripDetail trip, {required bool own}) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          void run(VoidCallback action) {
            Navigator.pop(sheetContext);
            action();
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    trip.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  title: Text(trip.isSaved ? 'Remove from saved' : 'Save trip'),
                  onTap: () => run(
                    () => _guarded(
                      'Sign in to save trips',
                      ref.read(tripDetailProvider(trip.id).notifier).toggleSave,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share'),
                  onTap: () => run(() => shareTrip(context, trip)),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Copy link'),
                  onTap: () => run(() => copyTripLink(context, trip)),
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Comments'),
                  onTap: () => run(() => showCommentsSheet(context, trip)),
                ),
                if (own)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(sheetContext).colorScheme.error,
                    ),
                    title: Text(
                      'Delete trip',
                      style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error,
                      ),
                    ),
                    onTap: () => run(() => _confirmDelete(trip)),
                  ),
              ],
            ),
          );
        },
      );

  Widget _buildContent(TripDetail trip) {
    final overview = _shownTab == 0;
    final notifier = ref.read(tripDetailProvider(trip.id).notifier);
    final me = ref.watch(authUserProvider.select((u) => u.valueOrNull?.id));
    final own = me != null && me == trip.authorId;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: overview
              ? _FullHeader(
                  trip: trip,
                  // Nobody follows themselves.
                  onFollow: own
                      ? null
                      : () => _guarded(
                          'Sign in to follow travellers',
                          notifier.toggleFollow,
                        ),
                  onLike: () =>
                      _guarded('Sign in to like trips', notifier.toggleLike),
                  onBack: _leave,
                  onMore: () => _showMore(trip, own: own),
                )
              : _CompactHeader(
                  trip: trip,
                  onLike: () =>
                      _guarded('Sign in to like trips', notifier.toggleLike),
                  onBack: _onBack,
                  onMore: () => _showMore(trip, own: own),
                ),
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
  const _CompactHeader({
    required this.trip,
    required this.onLike,
    required this.onBack,
    required this.onMore,
  });
  final TripDetail trip;
  final VoidCallback onLike;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 4),
            BackButton(onPressed: onBack),
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
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Share',
                onPressed: () => shareTrip(context, trip),
                icon: const Icon(Icons.ios_share),
              ),
            ),
            IconButton(
              tooltip: 'More',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz),
            ),
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
    required this.onBack,
    required this.onMore,
  });
  final TripDetail trip;

  /// Null on the caller's own trip, which hides the button.
  final VoidCallback? onFollow;
  final VoidCallback onLike;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              TripCoverImage(
                coverUrl: trip.coverUrl,
                coverPlaceId: trip.stops
                    .where((s) => s.placeId != null)
                    .firstOrNull
                    ?.placeId,
                widthPx: 1200,
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
                          BackButton(color: Colors.white, onPressed: onBack),
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
                          Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Share',
                              onPressed: () => shareTrip(context, trip),
                              icon: const Icon(Icons.ios_share),
                            ),
                          ),
                          IconButton(
                            tooltip: 'More',
                            onPressed: onMore,
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
                backgroundImage: trip.authorAvatarUrl.isEmpty
                    ? null
                    : NetworkImage(trip.authorAvatarUrl),
                onBackgroundImageError: trip.authorAvatarUrl.isEmpty
                    ? null
                    : (_, _) {},
                child: trip.authorAvatarUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'by ${trip.authorName}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (onFollow == null)
                const SizedBox.shrink()
              else if (trip.isFollowing)
                OutlinedButton(
                  onPressed: onFollow,
                  child: const Text('Following'),
                )
              else
                FilledButton(onPressed: onFollow, child: const Text('Follow')),
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
