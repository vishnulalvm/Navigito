import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../trip_detail/domain/entities/trip_detail.dart';
import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../../trip_detail/presentation/providers/trip_detail_providers.dart';
import '../../../trip_detail/presentation/widgets/google_maps_sheet.dart';
import '../../domain/entities/journey_progress.dart';
import '../providers/journey_providers.dart';
import '../widgets/journey_stop_tile.dart';

/// A trip being travelled: the stops as a timeline, ticked off one by one,
/// with navigation to the next.
class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage> {
  final _upcomingKey = GlobalKey();
  bool _scrolled = false;

  JourneyNotifier get _journey =>
      ref.read(journeyProvider(widget.tripId).notifier);

  @override
  void initState() {
    super.initState();
    // Opening the screen is what starts the journey.
    WidgetsBinding.instance.addPostFrameCallback((_) => _journey.start());
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRouter.home);

  /// Brings the stop being headed to into view, once, when the list first
  /// shows.
  void _scrollToUpcoming() {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _upcomingKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _reach(TripStop stop) {
    HapticFeedback.mediumImpact();
    _journey.reach(stop.id);
    showErrorSnack(context, 'Reached ${stop.title}');
  }

  Future<void> _undo(TripStop stop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Not reached yet?'),
        content: Text('${stop.title} goes back to being your next stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (ok == true) _journey.unreach(stop.id);
  }

  Future<void> _end({required bool finished}) async {
    if (!finished) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('End this trip?'),
          content: const Text(
            'Your progress will be cleared. You can start the journey again '
            'anytime.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('End trip'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _journey.end();
    showErrorSnack(context, finished ? 'Trip complete. Well done!' : null);
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripDetailProvider(widget.tripId));
    final progress = ref.watch(journeyProvider(widget.tripId));

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BackButton(onPressed: _leave),
              ),
              const Expanded(child: Center(child: Text('Could not load trip'))),
            ],
          ),
        ),
        data: (trip) => _content(trip, progress),
      ),
      bottomNavigationBar: switch (async.valueOrNull) {
        final trip? when trip.stops.isNotEmpty => _BottomBar(
          next: nextStop(trip.stops, progress),
          onEnd: (finished) => _end(finished: finished),
          onNavigate: (stop) =>
              openInGoogleMaps(context, TripMapsLinks.navigateTo(stop)),
        ),
        _ => null,
      },
    );
  }

  Widget _content(TripDetail trip, JourneyProgress? progress) {
    final stops = trip.stops;
    final next = nextStop(stops, progress);
    final lastReached = stops
        .where((s) => progress?.isReached(s.id) ?? false)
        .lastOrNull;
    if (next != null) _scrollToUpcoming();

    final children = <Widget>[];
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      // Multi-day trips get a heading where each day begins.
      if (trip.days > 1 && (i == 0 || stops[i - 1].day != s.day)) {
        children.add(_DayHeading(trip: trip, day: s.day));
      }
      final status = progress?.isReached(s.id) ?? false
          ? StopStatus.reached
          : s == next
          ? StopStatus.upcoming
          : StopStatus.later;
      children.add(
        JourneyStopTile(
          key: status == StopStatus.upcoming ? _upcomingKey : null,
          stop: s,
          status: status,
          isFirst: i == 0,
          isLast: i == stops.length - 1,
          lineBeforeDone:
              i > 0 && (progress?.isReached(stops[i - 1].id) ?? false),
          reachedAt: progress?.reachedAt[s.id],
          onNavigate: () =>
              openInGoogleMaps(context, TripMapsLinks.navigateTo(s)),
          onReached: () => _reach(s),
          onUndo: s == lastReached ? () => _undo(s) : null,
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            trip: trip,
            day: (next ?? stops.lastOrNull)?.day ?? 1,
            onBack: _leave,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          sliver: SliverList.list(children: children),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trip, required this.day, required this.onBack});

  final TripDetail trip;

  /// The day the next stop falls on.
  final int day;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final km = trip.distanceKm > 0
        ? trip.distanceKm
        : trip.stops.fold(0, (sum, s) => sum + (s.distanceKm ?? 0));
    final minutes = trip.stops.fold(
      0,
      (sum, s) => sum + (s.travelMinutes ?? 0),
    );
    final facts = [
      'Day $day',
      '${trip.stopCount} ${trip.stopCount == 1 ? 'Stop' : 'Stops'}',
      if (km > 0) '$km km',
      if (minutes > 0) '~${formatDrive(minutes)} driving',
    ];

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BackButton(onPressed: onBack),
                Expanded(
                  child: Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
              child: Text(
                facts.join('  •  '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.trip, required this.day});
  final TripDetail trip;
  final int day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = trip.startDate.add(Duration(days: day - 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'Day $day · ${DateFormat('d MMM (E)').format(date)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// End Trip, plus a card for the next stop that starts navigation to it.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.next,
    required this.onEnd,
    required this.onNavigate,
  });

  /// Null once every stop is reached.
  final TripStop? next;
  final void Function(bool finished) onEnd;
  final void Function(TripStop stop) onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = next == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Material(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: finished ? null : () => onNavigate(next!),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: finished
                            ? Row(
                                children: [
                                  const Icon(
                                    Icons.celebration_outlined,
                                    color: Color(0xFF2E9E5B),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'All stops reached',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            : _NextStop(stop: next!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => onEnd(finished),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      backgroundColor: finished
                          ? const Color(0xFF2E9E5B)
                          : const Color(0xFFE84A6A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: Icon(
                      finished ? Icons.flag : Icons.stop_rounded,
                      size: 22,
                    ),
                    label: Text(finished ? 'Finish' : 'End Trip'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextStop extends StatelessWidget {
  const _NextStop({required this.stop});
  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: stopColor(stop.type),
          child: Icon(stopIcon(stop.type), size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  'Next Stop',
                  if (stop.distanceKm != null) '${stop.distanceKm} km',
                  if (stop.travelMinutes != null)
                    formatDrive(stop.travelMinutes!),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 2),
              Text(
                stop.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: muted),
      ],
    );
  }
}
