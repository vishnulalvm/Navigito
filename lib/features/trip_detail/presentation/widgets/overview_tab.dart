import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/widgets/place_photos.dart';
import '../../domain/entities/trip_detail.dart';
import 'comments_section.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.trip});
  final TripDetail trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // One thumbnail per stop that has a photo (uploaded or live Google).
    final photos = [
      for (final s in trip.stops)
        ?stopPhotos(ref, uploaded: s.photoUrls, placeId: s.placeId).firstOrNull,
    ];
    final shown = photos.take(4).toList();
    final extra = photos.length - shown.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (trip.description.isNotEmpty) ...[
          Text(
            trip.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (shown.isNotEmpty) ...[
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
          const SizedBox(height: 20),
        ],
        const Divider(height: 1),
        const SizedBox(height: 16),
        CommentsSection(trip: trip),
      ],
    );
  }
}
