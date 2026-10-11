import 'package:flutter/material.dart';

import 'place_photos.dart';
import '../../domain/entities/trip.dart';

class TripCard extends StatefulWidget {
  const TripCard({super.key, required this.trip, this.onTap, this.onRoute});

  final Trip trip;

  /// Opens the trip; the whole card is the tap target.
  final VoidCallback? onTap;
  final VoidCallback? onRoute;

  static const _radius = 20.0;
  static const _imageAspect = 1.7;

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K'
      : '$n';

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  /// Card sinks slightly while a finger is on it.
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final category = trip.tags.isEmpty ? null : trip.tags.first;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TripCard._radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TripCard._radius - 8),
                  child: AspectRatio(
                    aspectRatio: TripCard._imageAspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Uploaded cover, or a live Google photo of the first
                        // stop; only loaded once the card is built on screen.
                        TripCoverImage(
                          coverUrl: trip.coverUrl,
                          coverPlaceId: trip.coverPlaceId,
                        ),
                        if (trip.photosCount > 1)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _PhotoCountBadge(count: trip.photosCount),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Facts live on the card, not over the photo, so they
                    // stay legible whatever the image looks like.
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Fact(
                          icon: Icons.calendar_today_outlined,
                          text:
                              '${trip.days} ${trip.days == 1 ? 'day' : 'days'}',
                        ),
                        _Fact(
                          icon: Icons.place_outlined,
                          text: '${trip.stops} stops',
                        ),
                        if (trip.distanceKm > 0)
                          _Fact(
                            icon: Icons.straighten,
                            text: '${trip.distanceKm} km',
                          ),
                        if (category != null) _CategoryChip(label: category),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (trip.description.isNotEmpty) ...[
                                Text(
                                  trip.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    backgroundImage:
                                        trip.authorAvatarUrl.isEmpty
                                        ? null
                                        : NetworkImage(trip.authorAvatarUrl),
                                    onBackgroundImageError:
                                        trip.authorAvatarUrl.isEmpty
                                        ? null
                                        : (_, _) {},
                                    child: trip.authorAvatarUrl.isEmpty
                                        ? Icon(
                                            Icons.person,
                                            size: 16,
                                            color: muted,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      trip.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: muted),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.thumb_up_alt_outlined,
                                    size: 16,
                                    color: muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    TripCard._compact(trip.likes),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _RouteButton(onPressed: widget.onRoute),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + label for one trip fact (days, stops, distance).
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
      ],
    );
  }
}

/// Icon + label naming the trip's category, e.g. "Cultural".
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  static IconData _iconFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('cultur')) return Icons.account_balance_outlined;
    if (c.contains('histor')) return Icons.museum_outlined;
    if (c.contains('nature') || c.contains('outdoor')) {
      return Icons.park_outlined;
    }
    if (c.contains('advent') || c.contains('hik')) return Icons.hiking;
    if (c.contains('beach')) return Icons.beach_access_outlined;
    if (c.contains('food') || c.contains('culinary')) {
      return Icons.restaurant_outlined;
    }
    if (c.contains('city') || c.contains('urban')) {
      return Icons.location_city_outlined;
    }
    if (c.contains('road')) return Icons.directions_car_outlined;
    if (c.contains('relax') || c.contains('wellness')) {
      return Icons.spa_outlined;
    }
    if (c.contains('night')) return Icons.nightlife_outlined;
    if (c.contains('shop')) return Icons.shopping_bag_outlined;
    return Icons.local_offer_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_iconFor(label), size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label[0].toUpperCase() + label.substring(1),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Dark glass badge on the cover showing how many photos the trip has.
class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '1/$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient pill that shows the trip's route on the map.
class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = HSLColor.fromColor(scheme.primary);
    final end = light
        .withLightness((light.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [scheme.primary, end]),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route, size: 20, color: scheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Route',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 20, color: scheme.onPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing stand-in shaped like a [TripCard], shown while trips load.
class TripCardSkeleton extends StatefulWidget {
  const TripCardSkeleton({super.key});

  @override
  State<TripCardSkeleton> createState() => _TripCardSkeletonState();
}

class _TripCardSkeletonState extends State<TripCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return FadeTransition(
      opacity: Tween(
        begin: 0.5,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(TripCard._radius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: TripCard._imageAspect,
              child: ColoredBox(color: scheme.surfaceContainerHighest),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(180, 16),
                  const SizedBox(height: 10),
                  bar(150, 12),
                  const SizedBox(height: 14),
                  bar(120, 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
