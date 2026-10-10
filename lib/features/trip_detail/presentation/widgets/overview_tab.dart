import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/trip_detail.dart';
import '../providers/trip_detail_providers.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.trip});
  final TripDetail trip;

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K'
      : '$n';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(tripDetailProvider(trip.id).notifier);
    final photos = trip.stops.map((s) => s.photoUrl).toList();
    final shown = photos.take(4).toList();
    final extra = photos.length - shown.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                trip.description,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in trip.tags)
                    Chip(label: Text(t), side: BorderSide.none),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 96,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            shown[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                          if (i == shown.length - 1 && extra > 0)
                            ColoredBox(
                              color: Colors.black54,
                              child: Center(
                                child: Text(
                                  '+$extra',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                InkWell(
                  onTap: notifier.toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        trip.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.pinkAccent,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_compact(trip.likes + (trip.isLiked ? 0 : -1))} likes',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.chat_bubble_outline),
                const SizedBox(width: 8),
                Text('${trip.comments}'),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: notifier.toggleSave,
                  icon: Icon(
                    trip.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: Text(trip.isSaved ? 'Saved' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
