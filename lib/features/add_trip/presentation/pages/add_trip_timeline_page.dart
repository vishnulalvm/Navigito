import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';
import '../providers/trip_draft_provider.dart';
import '../widgets/add_trip_bottom_action.dart';
import '../widgets/edit_stop_sheet.dart';
import '../widgets/step_progress.dart';
import '../widgets/stop_badge.dart';

/// Step 2: the stops laid out day by day. Drag a stop to reorder it or move
/// it to another day; tap it to change its kind or time.
class AddTripTimelinePage extends ConsumerWidget {
  const AddTripTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(tripDraftProvider);
    final items = _items(draft);
    final schedule = draft.schedule;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan your days'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(36),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: StepProgress(step: 2, label: 'Timeline'),
          ),
        ),
      ),
      body: Column(
        children: [
          _DaysStepper(days: draft.days),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: (from, to) =>
                  _onReorder(ref, items, from, to > from ? to - 1 : to),
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Material(
                  elevation: 6 * animation.value,
                  borderRadius: BorderRadius.circular(14),
                  child: child,
                ),
                child: child,
              ),
              itemBuilder: (context, i) => switch (items[i]) {
                _DayItem(:final day, :final count) => _DayHeader(
                  key: ValueKey('day-$day'),
                  day: day,
                  count: count,
                ),
                _StopItem(:final stop, :final index, :final lastOfDay) =>
                  _TimelineStop(
                    key: ValueKey(stop.id),
                    listIndex: i,
                    stop: stop,
                    time: schedule[index],
                    lastOfDay: lastOfDay,
                  ),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: AddTripBottomAction(
        label: 'Next: Details',
        onPressed: draft.stops.isEmpty
            ? null
            : () => context.push(AppRouter.addTripDetails),
      ),
    );
  }

  /// Day headers with that day's stops under them.
  static List<_Item> _items(TripDraft draft) {
    final items = <_Item>[];
    for (var day = 1; day <= draft.days; day++) {
      final dayStops = [
        for (final (i, s) in draft.stops.indexed)
          if (s.day == day) (i, s),
      ];
      items.add(_DayItem(day, dayStops.length));
      for (final (j, (i, s)) in dayStops.indexed) {
        items.add(_StopItem(s, i, lastOfDay: j == dayStops.length - 1));
      }
    }
    return items;
  }

  /// Moves the dragged row, then gives each stop the day of the header above
  /// it (a stop dropped above Day 1 joins Day 1).
  static void _onReorder(WidgetRef ref, List<_Item> items, int from, int to) {
    final moved = [...items];
    moved.insert(to, moved.removeAt(from));
    var day = 1;
    final stops = <DraftStop>[];
    for (final item in moved) {
      switch (item) {
        case _DayItem(day: final d):
          day = d;
        case _StopItem(:final stop):
          stops.add(stop.day == day ? stop : stop.copyWith(day: day));
      }
    }
    ref.read(tripDraftProvider.notifier).setTimeline(stops);
  }
}

sealed class _Item {
  const _Item();
}

class _DayItem extends _Item {
  const _DayItem(this.day, this.count);
  final int day;
  final int count;
}

class _StopItem extends _Item {
  const _StopItem(this.stop, this.index, {required this.lastOfDay});
  final DraftStop stop;

  /// Position in the whole trip, for its scheduled time.
  final int index;
  final bool lastOfDay;
}

class _DaysStepper extends ConsumerWidget {
  const _DaysStepper({required this.days});

  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(tripDraftProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip length', style: theme.textTheme.titleSmall),
                    Text(
                      'Changing it spreads stops evenly',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fewer days',
                onPressed: days > 1 ? () => notifier.setDays(days - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 56,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    '$days ${days == 1 ? 'day' : 'days'}',
                    key: ValueKey(days),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'More days',
                onPressed: days < TripDraft.maxDays
                    ? () => notifier.setDays(days + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.day, required this.count});

  final int day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Day $day',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (count > 0)
                  TextSpan(
                    text: '  ·  $count ${count == 1 ? 'stop' : 'stops'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Free day. Drag a stop here to plan it.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One stop on the timeline: time, a dot joined to the next stop of the day,
/// name and kind. Long-press anywhere or grab the handle to drag.
class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    super.key,
    required this.listIndex,
    required this.stop,
    required this.time,
    required this.lastOfDay,
  });

  final int listIndex;
  final DraftStop stop;
  final TimeOfDay time;
  final bool lastOfDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auto = stop.time == null;

    return ReorderableDelayedDragStartListener(
      index: listIndex,
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: () => showEditStopSheet(context, stop.id),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 16),
                SizedBox(
                  width: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      time.format(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        // Auto times are suggestions, set ones are firm.
                        color: auto ? scheme.onSurfaceVariant : scheme.primary,
                        fontWeight: auto ? FontWeight.w400 : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      const SizedBox(height: 2),
                      StopBadge(type: stop.type),
                      if (!lastOfDay)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 0, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          [
                            stop.type.label,
                            if (stop.subtitle.isNotEmpty) stop.subtitle,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: listIndex,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                    child: Icon(
                      Icons.drag_indicator,
                      color: scheme.onSurfaceVariant,
                    ),
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
