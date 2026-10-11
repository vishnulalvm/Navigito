import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../../../home/presentation/widgets/category_style.dart';
import '../../../home/presentation/widgets/place_photos.dart';
import '../../../journey/presentation/providers/journey_providers.dart';
import '../../domain/entities/trip_detail.dart';
import '../providers/trip_detail_providers.dart';
import '../widgets/google_maps_sheet.dart';
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
        bottomNavigationBar: _journeyBar(async.valueOrNull),
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

  /// Start journey (the stop-by-stop journey screen) and Google Maps
  /// (choose what to view), pinned under every tab.
  Widget? _journeyBar(TripDetail? trip) {
    if (trip == null || trip.stops.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    final inProgress = ref.watch(journeyProvider(trip.id)) != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.push(AppRouter.journey(trip.id)),
                  icon: const Icon(Icons.navigation_outlined),
                  label: Text(
                    inProgress ? 'Continue journey' : 'Start journey',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => showGoogleMapsSheet(context, trip),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Google Maps'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share'),
                  onTap: () => run(() => shareTrip(context, trip)),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Copy link'),
                  onTap: () => run(() => copyTripLink(context, trip)),
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
    void like() => _guarded('Sign in to like trips', notifier.toggleLike);
    void save() => _guarded('Sign in to save trips', notifier.toggleSave);

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
                  onLike: like,
                  onSave: save,
                  onBack: _leave,
                  onMore: () => _showMore(trip, own: own),
                )
              : _CompactHeader(
                  trip: trip,
                  onSave: save,
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

/// Round frosted-glass button floating on the cover photo.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: scheme.surface.withValues(alpha: 0.55),
            shape: CircleBorder(
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: Icon(icon, color: color ?? scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header on the Route, Stops and Photos tabs, leaving room for them.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.trip,
    required this.onSave,
    required this.onBack,
    required this.onMore,
  });
  final TripDetail trip;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              tooltip: trip.isSaved ? 'Saved' : 'Save',
              onPressed: onSave,
              icon: Icon(
                trip.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: trip.isSaved ? scheme.primary : null,
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Share',
                onPressed: () => shareTrip(context, trip),
                icon: const Icon(Icons.share_outlined),
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

/// Overview header: photo carousel, title with likes, author, and stats.
class _FullHeader extends StatelessWidget {
  const _FullHeader({
    required this.trip,
    required this.onFollow,
    required this.onLike,
    required this.onSave,
    required this.onBack,
    required this.onMore,
  });
  final TripDetail trip;

  /// Null on the caller's own trip, which hides the button.
  final VoidCallback? onFollow;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback onMore;

  static const _coverHeight = 340.0;

  /// How far the rounded content sheet rides up over the photo.
  static const _overlap = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = trip.tags.where((t) => t.isNotEmpty).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _coverHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CoverPhoto(trip: trip),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      children: [
                        _CircleAction(
                          icon: Icons.arrow_back_ios_new,
                          tooltip: 'Back',
                          onPressed: onBack,
                        ),
                        const Spacer(),
                        _CircleAction(
                          icon: trip.isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          tooltip: trip.isSaved ? 'Saved' : 'Save',
                          color: trip.isSaved ? scheme.primary : null,
                          onPressed: onSave,
                        ),
                        Builder(
                          builder: (context) => _CircleAction(
                            icon: Icons.share_outlined,
                            tooltip: 'Share',
                            onPressed: () => shareTrip(context, trip),
                          ),
                        ),
                        _CircleAction(
                          icon: Icons.more_horiz,
                          tooltip: 'More',
                          onPressed: onMore,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Rounded top of the content sheet, overlapping the photo.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _overlap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_overlap),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  trip.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _LikesPill(trip: trip, onTap: onLike),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
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
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onFollow != null)
                trip.isFollowing
                    ? OutlinedButton(
                        onPressed: onFollow,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Following'),
                      )
                    : FilledButton.tonal(
                        onPressed: onFollow,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Follow'),
                      ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (i, stat) in [
                _StatPill(
                  icon: Icons.calendar_today_outlined,
                  label: '${trip.days} ${trip.days == 1 ? 'Day' : 'Days'}',
                ),
                _StatPill(
                  icon: Icons.place_outlined,
                  label:
                      '${trip.stopCount} ${trip.stopCount == 1 ? 'Stop' : 'Stops'}',
                ),
                _StatPill(
                  icon: Icons.route_outlined,
                  label: '${trip.distanceKm} km',
                ),
                if (category != null)
                  _StatPill(
                    icon: categoryIcon(category),
                    label: categoryLabel(category),
                    accent: tagAccents.first,
                  ),
              ].indexed) ...[
                if (i > 0)
                  VerticalDivider(
                    width: 24,
                    indent: 10,
                    endIndent: 10,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                stat,
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The trip's single cover photo, with a soft top fade for the buttons.
class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({required this.trip});
  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        // Keeps the round buttons readable on bright photos.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment(0, -0.3),
                colors: [Colors.black26, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Like toggle showing the count, e.g. "♥ 12".
class _LikesPill extends StatelessWidget {
  const _LikesPill({required this.trip, required this.onTap});
  final TripDetail trip;
  final VoidCallback onTap;

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K'
      : '$n';

  @override
  Widget build(BuildContext context) {
    const pink = Colors.pinkAccent;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              trip.isLiked ? Icons.favorite : Icons.favorite_border,
              color: pink,
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              _compact(trip.likes),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Borderless stat such as "4 Stops"; coloured when given an [accent].
class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, this.accent});
  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fg = accent == null
        ? scheme.onSurface
        : dark
        ? Color.lerp(accent, Colors.white, 0.45)!
        : accent!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
      ],
    );
  }
}
