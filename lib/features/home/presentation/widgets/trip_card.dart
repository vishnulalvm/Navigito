import 'package:flutter/material.dart';

import '../../domain/entities/trip.dart';

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onFavorite,
    this.onTap,
    this.onView,
    this.onRoute,
  });

  final Trip trip;
  final VoidCallback onFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onView;
  final VoidCallback? onRoute;

  static const _radius = 10.0;

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K'
      : '$n';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = '${trip.days} ${trip.days == 1 ? 'day' : 'days'}';
    final meta =
        '$days · ${trip.stops} stops'
        '${trip.distanceKm > 0 ? ' · ${trip.distanceKm} km' : ''}';
    final overlayStyle = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    trip.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: scheme.surfaceContainerHighest),
                  ),
                  // Just enough scrim to keep the small labels legible.
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black45],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 7,
                    child: Text(meta, style: overlayStyle),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 7,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(_compact(trip.likes), style: overlayStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      InkResponse(
                        onTap: onFavorite,
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            trip.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: trip.isFavorite
                                ? Colors.pinkAccent
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(trip.authorAvatarUrl),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          trip.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _SquareAction(
                        icon: Icons.visibility_outlined,
                        tooltip: 'View trip',
                        onPressed: onView,
                      ),
                      const SizedBox(width: 6),
                      _SquareAction(
                        icon: Icons.route_outlined,
                        tooltip: 'Show route on map',
                        onPressed: onRoute,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small bordered icon button with a tight corner radius.
class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 30,
            child: Icon(icon, size: 17, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
