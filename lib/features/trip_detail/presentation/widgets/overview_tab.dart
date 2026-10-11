import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/widgets/place_photos.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../../domain/entities/trip_detail.dart';
import '../providers/trip_detail_providers.dart';
import 'comments_sheet.dart';

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
    // One thumbnail per stop that has a photo (uploaded or live Google).
    final photos = [
      for (final s in trip.stops)
        ?stopPhotos(ref, uploaded: s.photoUrls, placeId: s.placeId).firstOrNull,
    ];
    final shown = photos.take(4).toList();
    final extra = photos.length - shown.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (trip.description.isNotEmpty) ...[
                Text(
                  trip.description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
              ],
              if (trip.tags.isNotEmpty) ...[
                // Filled pills: a borderless Material 3 chip has no fill and
                // would show only its text.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in trip.tags.where((t) => t.isNotEmpty))
                      Chip(
                        label: Text(t[0].toUpperCase() + t.substring(1)),
                        backgroundColor: scheme.secondaryContainer,
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (shown.isNotEmpty)
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
                            // Thumbnails may skip the credit; the Photos tab
                            // shows it.
                            PlacePhotoImage(
                              photo: shown[i],
                              widthPx: 300,
                              credit: false,
                            ),
                            if (i == shown.length - 1 && extra > 0)
                              ColoredBox(
                                color: Colors.black54,
                                child: Center(
                                  child: Text(
                                    '+$extra',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: Colors.white),
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
                  onTap: () async {
                    if (await ensureSignedIn(
                      context,
                      ref,
                      reason: 'Sign in to like trips',
                    )) {
                      final error = await notifier.toggleLike();
                      if (context.mounted) showErrorSnack(context, error);
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        trip.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.pinkAccent,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Text('${_compact(trip.likes)} likes'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showCommentsSheet(context, trip),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline),
                        const SizedBox(width: 8),
                        Text(_compact(trip.comments)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    if (await ensureSignedIn(
                      context,
                      ref,
                      reason: 'Sign in to save trips',
                    )) {
                      final error = await notifier.toggleSave();
                      if (context.mounted) showErrorSnack(context, error);
                    }
                  },
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
