import 'package:flutter/material.dart';

import '../../../home/domain/entities/trip.dart';

enum _TripMenu { share, remove }

class MyTripTile extends StatelessWidget {
  const MyTripTile({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onFavorite,
    required this.onRemove,
  });

  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = '${trip.days} ${trip.days == 1 ? 'Day' : 'Days'}';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 128,
          child: Row(
            children: [
              SizedBox(
                width: 132,
                height: double.infinity,
                child: Image.network(
                  trip.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: scheme.surfaceContainerHighest),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              trip.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onFavorite,
                            icon: Icon(
                              trip.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.pinkAccent,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$days · ${trip.stops} Stops · ${trip.distanceKm} km',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundImage: NetworkImage(trip.authorAvatarUrl),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'by ${trip.authorName}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          PopupMenuButton<_TripMenu>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (m) {
                              if (m == _TripMenu.remove) onRemove();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _TripMenu.share,
                                child: Text('Share'),
                              ),
                              PopupMenuItem(
                                value: _TripMenu.remove,
                                child: Text('Remove'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
