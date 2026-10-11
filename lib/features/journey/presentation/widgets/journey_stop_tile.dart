import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/widgets/place_photos.dart';
import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';

/// Where a stop stands on the journey.
enum StopStatus { reached, upcoming, later }

/// "1h 30m", "45m".
String formatDrive(int minutes) => minutes >= 60
    ? '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}'
    : '${minutes}m';

/// Stop marker colour; the start gets the route's blue instead of white.
Color stopColor(StopType type) =>
    type == StopType.start ? const Color(0xFF2F6BFF) : type.color;

IconData stopIcon(StopType type) =>
    type == StopType.start ? Icons.location_on : type.icon;

/// One stop on the journey timeline: time, marker, photo, details, and the
/// actions that fit its [status].
class JourneyStopTile extends StatelessWidget {
  const JourneyStopTile({
    super.key,
    required this.stop,
    required this.status,
    required this.isFirst,
    required this.isLast,
    required this.lineBeforeDone,
    this.reachedAt,
    this.onNavigate,
    this.onReached,
    this.onUndo,
  });

  final TripStop stop;
  final StopStatus status;
  final bool isFirst;
  final bool isLast;

  /// Whether the timeline leading into this stop is travelled.
  final bool lineBeforeDone;
  final DateTime? reachedAt;
  final VoidCallback? onNavigate;
  final VoidCallback? onReached;

  /// Set on the latest reached stop only, so progress stays in order.
  final VoidCallback? onUndo;

  static const _timeWidth = 64.0; // Includes the 16px screen inset.
  static const _railWidth = 44.0;
  static const _thumb = 64.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upcoming = status == StopStatus.upcoming;
    final done = scheme.primary;
    final pending = scheme.outlineVariant;

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inside the highlight's 8px margin, so columns line up with other rows.
          SizedBox(
            width: _timeWidth - (upcoming ? 8 : 0),
            child: _Time(hhmm: stop.time, left: upcoming ? 8 : 16),
          ),
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  color: isFirst
                      ? Colors.transparent
                      : (lineBeforeDone ? done : pending),
                ),
                _Marker(
                  stop: stop,
                  highlighted: upcoming,
                  reached: status == StopStatus.reached,
                  onTap: onUndo,
                ),
                Expanded(
                  child: Container(
                    width: 3,
                    color: isLast
                        ? Colors.transparent
                        : (status == StopStatus.reached ? done : pending),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Details(stop: stop)),
                      const SizedBox(width: 12),
                      _Thumb(stop: stop, size: _thumb),
                    ],
                  ),
                  if (upcoming) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: onNavigate,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                            textStyle: Theme.of(context).textTheme.labelMedium,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.near_me_outlined, size: 16),
                          label: const Text('Navigate'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: onReached,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                            textStyle: Theme.of(context).textTheme.labelMedium,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: const Text('Mark reached'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: upcoming ? 8 : 16),
        ],
      ),
    );

    if (!upcoming) return row;
    // The stop being headed to sits on a soft highlight.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: row,
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.hhmm, required this.left});
  final String hhmm;
  final double left;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = hhmm.split(':');
    final h = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final small = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.only(top: 22, left: left),
      child: h == null
          ? Text('--', style: style)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0')}:${parts[1]}',
                  style: style,
                ),
                Text(h >= 12 ? 'PM' : 'AM', style: small),
              ],
            ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.stop,
    required this.highlighted,
    required this.reached,
    this.onTap,
  });
  final TripStop stop;
  final bool highlighted;

  /// Shows a check instead of the stop's category icon.
  final bool reached;

  /// Undoes the reach; set on the latest reached stop only.
  final VoidCallback? onTap;

  static const _green = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final color = reached ? _green : stopColor(stop.type);
    return GestureDetector(
      onTap: reached ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          reached ? Icons.check : stopIcon(stop.type),
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.stop, required this.size});
  final TripStop stop;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = stopPhotos(
      ref,
      uploaded: stop.photoUrls,
      placeId: stop.placeId,
    ).firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: size,
        child: photo == null
            ? const PhotoPlaceholder(icon: true)
            // A thumbnail may skip the credit; the Photos tab shows it.
            : PlacePhotoImage(photo: photo, widthPx: 200, credit: false),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.stop});
  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final drive = [
      if (stop.distanceKm != null) '${stop.distanceKm} km',
      if (stop.travelMinutes != null) formatDrive(stop.travelMinutes!),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stop.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (stop.subtitle case final sub? when sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
        if (drive.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.directions_car_outlined, size: 15, color: muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  drive,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
