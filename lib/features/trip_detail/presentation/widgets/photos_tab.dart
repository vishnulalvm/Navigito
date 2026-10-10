import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/widgets/place_photos.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/entities/trip_stop.dart';

class PhotosTab extends ConsumerStatefulWidget {
  const PhotosTab({super.key, required this.trip});
  final TripDetail trip;

  @override
  ConsumerState<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends ConsumerState<PhotosTab> {
  StopType? _filter; // null = all

  static String _time12(String hhmm) {
    if (!hhmm.contains(':')) return '';
    final p = hhmm.split(':');
    final h = int.parse(p[0]);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${p[1]} ${h >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Every photo of every matching stop: its uploads, or Google's live ones.
    final photos = [
      for (final s in widget.trip.stops)
        if (s.type != StopType.start && (_filter == null || s.type == _filter))
          for (final p in stopPhotos(
            ref,
            uploaded: s.photoUrls,
            placeId: s.placeId,
          ))
            (stop: s, photo: p),
    ];

    Widget chip(String label, StopType? type) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == type,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = type),
      ),
    );

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            children: [
              chip('All', null),
              chip('Attractions', StopType.attraction),
              chip('Food', StopType.food),
              chip('Stays', StopType.stay),
            ],
          ),
        ),
        if (photos.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No photos yet',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final (:stop, :photo) = photos[i];
                final s = stop;
                final caption = [
                  _time12(s.time),
                  if (photo.author case final a?) '© $a',
                ].where((t) => t.isNotEmpty).join(' · ');
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Credited in the caption below instead.
                      PlacePhotoImage(
                        photo: photo,
                        widthPx: 500,
                        credit: false,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (caption.isNotEmpty)
                              Text(
                                caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
