import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';
import '../providers/trip_draft_provider.dart';
import 'stop_badge.dart';
import 'stop_photo_picker.dart';

Future<void> showEditStopSheet(BuildContext context, String stopId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _EditStopSheet(stopId: stopId),
  );
}

/// Removes a stop and offers to put it back.
void removeStopWithUndo(BuildContext context, WidgetRef ref, String stopId) {
  final notifier = ref.read(tripDraftProvider.notifier);
  final removed = notifier.removeStop(stopId);
  if (removed == null) return;
  final (index, stop) = removed;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Removed ${stop.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.insertStop(index, stop),
        ),
      ),
    );
}

/// Edits one stop live: its kind and time. The day is set by dragging in the
/// timeline.
class _EditStopSheet extends ConsumerWidget {
  const _EditStopSheet({required this.stopId});

  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = ref.watch(tripDraftProvider);
    final index = draft.stops.indexWhere((s) => s.id == stopId);
    if (index < 0) return const SizedBox.shrink();
    final stop = draft.stops[index];
    final time = draft.schedule[index];
    final notifier = ref.read(tripDraftProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StopBadge(type: stop.type, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (stop.subtitle.isNotEmpty)
                        Text(
                          stop.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<StopType>(
                showSelectedIcon: false,
                segments: [
                  for (final t in const [
                    StopType.attraction,
                    StopType.food,
                    StopType.stay,
                  ])
                    ButtonSegment(
                      value: t,
                      label: Text(t.label),
                      icon: Icon(t.icon, size: 16),
                    ),
                ],
                selected: {stop.type},
                onSelectionChanged: (s) =>
                    notifier.updateStop(stop.copyWith(type: s.first)),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text('Day ${stop.day} · ${time.format(context)}'),
              subtitle: Text(
                stop.time == null
                    ? 'Auto · 2 h after the stop before'
                    : 'Set by you',
              ),
              trailing: stop.time == null
                  ? const Icon(Icons.edit_outlined)
                  : TextButton(
                      onPressed: () =>
                          notifier.updateStop(stop.copyWith(time: () => null)),
                      child: const Text('Auto'),
                    ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: time,
                );
                if (picked != null) {
                  notifier.updateStop(stop.copyWith(time: () => picked));
                }
              },
            ),
            const SizedBox(height: 12),
            StopPhotoPicker(stop: stop),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: () {
                removeStopWithUndo(context, ref, stop.id);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove stop'),
            ),
          ],
        ),
      ),
    );
  }
}
