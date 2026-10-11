import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/widgets/place_photos.dart';
import '../../domain/entities/trip_detail.dart';
import 'comments_section.dart';

/// Overview content: about, photo strip and comments. It does not scroll on
/// its own; the page scrolls it together with the header above.
class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({super.key, required this.trip, this.onSeePhotos});
  final TripDetail trip;

  /// Opens the Photos tab; hides the "See all" link when null.
  final VoidCallback? onSeePhotos;

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> {
  /// Descriptions longer than this fold behind "Read more".
  static const _foldAt = 140;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // One thumbnail per stop that has a photo (uploaded or live Google).
    final photos = [
      for (final s in trip.stops)
        ?stopPhotos(ref, uploaded: s.photoUrls, placeId: s.placeId).firstOrNull,
    ];
    final shown = photos.take(4).toList();
    final extra = photos.length - shown.length;
    final foldable = trip.description.length > _foldAt;

    Widget heading(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trip.description.isNotEmpty) ...[
            heading('About this trip'),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Text(
                trip.description,
                maxLines: foldable && !_expanded ? 4 : null,
                overflow: TextOverflow.fade,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.55,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (foldable)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Show less' : 'Read more'),
                ),
              ),
            const SizedBox(height: 24),
          ],
          if (shown.isNotEmpty) ...[
            heading(
              'Photos',
              trailing: widget.onSeePhotos == null
                  ? null
                  : TextButton(
                      onPressed: widget.onSeePhotos,
                      child: const Text('See all'),
                    ),
            ),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: widget.onSeePhotos,
                    child: SizedBox(
                      width: 104,
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
            ),
            const SizedBox(height: 24),
          ],
          const Divider(height: 1),
          const SizedBox(height: 20),
          CommentsSection(trip: trip),
        ],
      ),
    );
  }
}
