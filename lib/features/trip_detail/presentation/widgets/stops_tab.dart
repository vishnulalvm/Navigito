import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../home/presentation/widgets/place_photos.dart';

import '../../domain/entities/trip_detail.dart';
import '../../domain/entities/trip_stop.dart';
import 'stop_style.dart';

class StopsTab extends StatelessWidget {
  const StopsTab({super.key, required this.trip});
  final TripDetail trip;

  String _duration(int m) => m >= 60
      ? '${m ~/ 60}h ${m % 60 == 0 ? '' : '${m % 60}m'}'.trim()
      : '${m}m';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final children = <Widget>[];

    for (var day = 1; day <= trip.days; day++) {
      final stops = trip.stops.where((s) => s.day == day).toList();
      if (stops.isEmpty) continue;
      final date = trip.startDate.add(Duration(days: day - 1));
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Day $day · ${DateFormat('d MMM (E)').format(date)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (var i = 0; i < stops.length; i++) {
        final s = stops[i];
        final last = i == stops.length - 1;
        children.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 16),
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(s.time, style: theme.textTheme.bodyMedium),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: s.type.color,
                          shape: BoxShape.circle,
                        ),
                        child: s.type == StopType.start
                            ? null
                            : Icon(s.type.icon, size: 15, color: Colors.white),
                      ),
                      if (!last)
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
                    padding: const EdgeInsets.only(bottom: 22, left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s.subtitle != null)
                          Text(
                            s.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (s.travelMinutes != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_duration(s.travelMinutes!)} · ${s.distanceKm} km',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _StopThumb(stop: s),
              ],
            ),
          ),
        );
      }
    }
    return ListView(children: [...children, const SizedBox(height: 24)]);
  }
}

/// The stop's first photo, uploaded or live from Google; nothing if none.
class _StopThumb extends ConsumerWidget {
  const _StopThumb({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = stopPhotos(
      ref,
      uploaded: stop.photoUrls,
      placeId: stop.placeId,
    ).firstOrNull;
    if (photo == null) return const SizedBox(width: 16);
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: 76,
          // A thumbnail may skip the credit; the Photos tab shows it.
          child: PlacePhotoImage(photo: photo, widthPx: 240, credit: false),
        ),
      ),
    );
  }
}
