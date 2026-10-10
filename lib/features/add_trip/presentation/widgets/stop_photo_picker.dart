import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../home/presentation/widgets/place_photos.dart';
import '../../domain/repositories/add_trip_repository.dart';
import '../../domain/usecases/stop_photos.dart';
import '../providers/photo_uploads_provider.dart';
import '../providers/trip_draft_provider.dart';

/// A stop's photos while planning: the user's uploads (up to 3), or else a
/// preview of Google's for its place, and a slot to add more. Picks are
/// resized on the phone and uploaded straight away, so publishing the trip
/// doesn't wait on them.
class StopPhotoPicker extends ConsumerStatefulWidget {
  const StopPhotoPicker({super.key, required this.stop});

  final DraftStop stop;

  @override
  ConsumerState<StopPhotoPicker> createState() => _StopPhotoPickerState();
}

class _StopPhotoPickerState extends ConsumerState<StopPhotoPicker> {
  static const _tile = 84.0;

  /// Long side and JPEG quality for uploads: sharp on a phone, ~300 KB.
  static const _maxSide = 1600.0;
  static const _quality = 80;

  final _picker = ImagePicker();

  AddTripRepository get _repo => sl<AddTripRepository>();
  TripDraftNotifier get _draft => ref.read(tripDraftProvider.notifier);

  int get _room =>
      DraftStop.maxPhotos -
      widget.stop.photoUrls.length -
      ref.read(photoUploadsProvider.notifier).pendingFor(widget.stop.id);

  Future<void> _add() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final List<XFile> picked;
    try {
      picked = source == ImageSource.gallery
          ? _room > 1
                ? await _picker.pickMultiImage(
                    maxWidth: _maxSide,
                    maxHeight: _maxSide,
                    imageQuality: _quality,
                    limit: _room,
                  )
                : [
                    ?await _picker.pickImage(
                      source: source,
                      maxWidth: _maxSide,
                      maxHeight: _maxSide,
                      imageQuality: _quality,
                    ),
                  ]
          : [
              ?await _picker.pickImage(
                source: source,
                maxWidth: _maxSide,
                maxHeight: _maxSide,
                imageQuality: _quality,
              ),
            ];
    } catch (_) {
      if (mounted) {
        showErrorSnack(context, 'Could not open photos. Check the permission.');
      }
      return;
    }
    // The gallery limit isn't honoured everywhere.
    await Future.wait(picked.take(_room).map(_upload));
  }

  Future<void> _upload(XFile file) async {
    // Keep the messenger: the sheet may be closed before the upload ends.
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await file.readAsBytes();
    final png = file.mimeType == 'image/png' || file.path.endsWith('.png');
    final error = await ref
        .read(photoUploadsProvider.notifier)
        .upload(
          widget.stop.id,
          bytes,
          contentType: png ? 'image/png' : 'image/jpeg',
        );
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _remove(String url) {
    _draft.removePhoto(widget.stop.id, url);
    DeleteStopPhoto(_repo)(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uploads = widget.stop.photoUrls;
    final uploading =
        ref.watch(photoUploadsProvider)[widget.stop.id] ?? const [];
    final hasOwn = uploads.isNotEmpty || uploading.isNotEmpty;
    // Google's are only a preview: shown while the user has none of theirs.
    final google = hasOwn
        ? const []
        : stopPhotos(ref, uploaded: const [], placeId: widget.stop.placeId);

    final String hint;
    if (hasOwn) {
      hint = 'Your photos show on this stop.';
    } else if (google.isNotEmpty) {
      hint = 'From Google Maps · add yours to replace them';
    } else {
      hint = 'No photos found for this place. Add yours so others can see it.';
    }

    Widget tile(Widget child, {VoidCallback? onRemove}) => SizedBox.square(
      dimension: _tile,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in uploads)
              tile(
                Image.network(url, fit: BoxFit.cover),
                onRemove: () => _remove(url),
              ),
            for (final bytes in uploading)
              tile(
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes, fit: BoxFit.cover),
                    const ColoredBox(color: Colors.black38),
                    const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final photo in google)
              tile(
                Opacity(
                  opacity: 0.85,
                  child: PlacePhotoImage(photo: photo, widthPx: 240),
                ),
              ),
            if (_room > 0)
              SizedBox.square(
                dimension: _tile,
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _add,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
