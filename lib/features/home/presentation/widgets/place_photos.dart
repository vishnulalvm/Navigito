import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/place_photo.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_place_photos.dart';

/// Live Google photos of a place, looked up once per session (the lookup is
/// free; Google forbids storing the result).
final placePhotosProvider = FutureProvider.family<List<PlacePhoto>, String>((
  ref,
  placeId,
) async {
  final result = await GetPlacePhotos(sl<HomeRepository>())(placeId);
  return result.getOrElse((_) => const []);
});

/// A stop's photos: the ones its author uploaded, or else Google's photos of
/// its place. Uploads win, so a stop with them never costs a Google load.
List<PlacePhoto> stopPhotos(
  WidgetRef ref, {
  required List<String> uploaded,
  String? placeId,
}) {
  if (uploaded.isNotEmpty) {
    return [for (final u in uploaded) PlacePhoto.uploaded(u)];
  }
  if (placeId == null) return const [];
  return ref.watch(placePhotosProvider(placeId)).valueOrNull ?? const [];
}

/// [photo] filling its box, fading in, credited when it's Google's.
class PlacePhotoImage extends StatelessWidget {
  const PlacePhotoImage({
    super.key,
    required this.photo,
    required this.widthPx,
    this.credit = true,
  });

  final PlacePhoto photo;

  /// Requested width; a Google load costs the same at any size, but smaller
  /// ones arrive faster and keep the in-memory cache small.
  final int widthPx;

  /// Google lets tiny thumbnails skip the credit; larger photos must show it.
  final bool credit;

  @override
  Widget build(BuildContext context) {
    final author = photo.author;
    return Stack(
      fit: StackFit.expand,
      children: [
        const PhotoPlaceholder(),
        Image.network(
          photo.url(widthPx: widthPx),
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, sync) => sync
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                ),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        if (credit && photo.isGoogle && author != null)
          Positioned(
            left: 6,
            bottom: 4,
            right: 6,
            child: Text(
              '© $author',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ),
      ],
    );
  }
}

/// A trip's cover: its uploaded one, or else a live Google photo of its first
/// stop with a place, or else a plain placeholder.
class TripCoverImage extends ConsumerWidget {
  const TripCoverImage({
    super.key,
    required this.coverUrl,
    required this.coverPlaceId,
    this.widthPx = 800,
    this.credit = true,
  });

  final String coverUrl;
  final String? coverPlaceId;
  final int widthPx;
  final bool credit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = stopPhotos(
      ref,
      uploaded: [if (coverUrl.isNotEmpty) coverUrl],
      placeId: coverPlaceId,
    );
    return photos.isEmpty
        ? const PhotoPlaceholder(icon: true)
        : PlacePhotoImage(
            photo: photos.first,
            widthPx: widthPx,
            credit: credit,
          );
  }
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.icon = false});

  /// Shows a landscape glyph, for boxes that will stay empty.
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: icon
          ? Center(
              child: Icon(
                Icons.landscape_outlined,
                size: 32,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            )
          : null,
    );
  }
}
