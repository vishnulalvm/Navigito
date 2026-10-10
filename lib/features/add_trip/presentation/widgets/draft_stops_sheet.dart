import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/map_sheet.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';
import '../providers/trip_draft_provider.dart';
import 'edit_stop_sheet.dart';
import 'step_progress.dart';
import 'stop_badge.dart';

/// Step 1's sheet: the stops added so far, in visiting order. Drag to
/// reorder, swipe or ✕ to remove.
class DraftStopsSheet extends ConsumerWidget {
  const DraftStopsSheet({
    super.key,
    required this.controller,
    required this.bottomInset,
    required this.onNext,
    required this.onStopTap,
    this.lastAddedId,
  });

  final MapSheetController controller;
  final double bottomInset;
  final VoidCallback onNext;
  final ValueChanged<DraftStop> onStopTap;

  /// Briefly highlighted, so the user sees where their pick went.
  final String? lastAddedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(tripDraftProvider.select((d) => d.stops));

    return MapSheet(
      controller: controller,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Title(count: stops.length),
                  const SizedBox(height: 6),
                  const SizedBox(
                    width: 150,
                    child: StepProgress(step: 1, label: 'Places'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedScale(
              scale: stops.isEmpty ? 0.94 : 1,
              duration: const Duration(milliseconds: 200),
              child: FilledButton.icon(
                onPressed: stops.isEmpty ? null : onNext,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
      slivers: [
        if (stops.isEmpty)
          const SliverToBoxAdapter(child: _EmptyHint())
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, bottomInset),
            sliver: SliverReorderableList(
              itemCount: stops.length,
              onReorderItem: (from, to) =>
                  ref.read(tripDraftProvider.notifier).reorder(from, to),
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Material(
                  elevation: 6 * animation.value,
                  borderRadius: BorderRadius.circular(14),
                  child: child,
                ),
                child: child,
              ),
              itemBuilder: (context, i) => _StopTile(
                key: ValueKey(stops[i].id),
                stop: stops[i],
                index: i,
                highlight: stops[i].id == lastAddedId,
                onTap: () => onStopTap(stops[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Your stops',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        // The count pops when a stop is added.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: count == 0
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(count),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StopTile extends ConsumerStatefulWidget {
  const _StopTile({
    super.key,
    required this.stop,
    required this.index,
    required this.highlight,
    required this.onTap,
  });

  final DraftStop stop;
  final int index;
  final bool highlight;
  final VoidCallback onTap;

  @override
  ConsumerState<_StopTile> createState() => _StopTileState();
}

class _StopTileState extends ConsumerState<_StopTile>
    with SingleTickerProviderStateMixin {
  /// Slides a just-added stop in and fades its highlight out.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: widget.highlight ? 0 : 1,
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stop = widget.stop;
    final enter = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
    );

    return SizeTransition(
      sizeFactor: enter,
      child: FadeTransition(
        opacity: enter,
        child: Dismissible(
          key: ValueKey('dismiss-${stop.id}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => removeStopWithUndo(context, ref, stop.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          ),
          child: AnimatedBuilder(
            animation: _intro,
            builder: (context, child) => Material(
              color: Color.lerp(
                scheme.primaryContainer,
                scheme.surface,
                Curves.easeIn.transform(_intro.value),
              ),
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
                child: Row(
                  children: [
                    StopBadge(type: stop.type, number: widget.index + 1),
                    const SizedBox(width: 12),
                    Expanded(
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
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          removeStopWithUndo(context, ref, stop.id),
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                        child: Icon(
                          Icons.drag_handle,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
      child: Column(
        children: [
          Icon(Icons.add_location_alt_outlined, size: 44, color: muted),
          const SizedBox(height: 12),
          Text(
            'Search above or tap the map to add your first stop',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Add places in the order you\'ll visit them. You can reorder '
            'and plan the days next.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
