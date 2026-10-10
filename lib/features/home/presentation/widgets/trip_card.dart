import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'place_photos.dart';
import '../../domain/entities/trip.dart';

class TripCard extends StatefulWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onFavorite,
    this.onTap,
    this.onRoute,
  });

  final Trip trip;
  final VoidCallback onFavorite;

  /// Opens the trip; the whole card is the tap target.
  final VoidCallback? onTap;
  final VoidCallback? onRoute;

  static const _radius = 16.0;
  static const _imageAspect = 2.0;

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
              AspectRatio(
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
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _FavoriteButton(
                        isFavorite: trip.isFavorite,
                        onPressed: widget.onFavorite,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Facts live on the card, not over the photo, so they
                    // stay legible whatever the image looks like.
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: scheme.surfaceContainerHighest,
                          backgroundImage: trip.authorAvatarUrl.isEmpty
                              ? null
                              : NetworkImage(trip.authorAvatarUrl),
                          onBackgroundImageError: trip.authorAvatarUrl.isEmpty
                              ? null
                              : (_, _) {},
                          child: trip.authorAvatarUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            trip.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          TripCard._compact(trip.likes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: widget.onRoute,
                          icon: const Icon(Icons.route_outlined, size: 18),
                          label: const Text('Route'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
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
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

/// Round save button floating on the cover photo; the white backing keeps it
/// visible on any image, and the heart pops when toggled.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isFavorite ? 'Remove from favourites' : 'Add to favourites',
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: SizedBox.square(
            dimension: 38,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isFavorite),
                size: 20,
                color: isFavorite ? Colors.pinkAccent : Colors.black87,
              ),
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
