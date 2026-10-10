import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/add_trip_repository.dart';
import '../../domain/usecases/stop_photos.dart';
import 'trip_draft_provider.dart';

/// Stop photos still uploading, by stop id, as local previews. Lives with
/// the draft rather than the sheet that started them, so closing the sheet
/// mid-upload still lands the photo on its stop.
class PhotoUploadsNotifier extends Notifier<Map<String, List<Uint8List>>> {
  @override
  Map<String, List<Uint8List>> build() => const {};

  int pendingFor(String stopId) => state[stopId]?.length ?? 0;

  bool get busy => state.values.any((p) => p.isNotEmpty);

  /// Uploads [bytes] and adds the photo to the stop. Returns the error
  /// message, or null on success.
  Future<String?> upload(
    String stopId,
    Uint8List bytes, {
    required String contentType,
  }) async {
    final repo = sl<AddTripRepository>();
    _set(stopId, [...?state[stopId], bytes]);
    final result = await UploadStopPhoto(repo)(bytes, contentType: contentType);
    _set(stopId, [
      for (final b in state[stopId] ?? const <Uint8List>[])
        if (!identical(b, bytes)) b,
    ]);
    return result.fold((f) => f.message, (url) {
      // The stop may be full or removed by now; don't keep an unused file.
      if (!ref.read(tripDraftProvider.notifier).addPhoto(stopId, url)) {
        DeleteStopPhoto(repo)(url);
      }
      return null;
    });
  }

  void _set(String stopId, List<Uint8List> previews) =>
      state = {...state, stopId: previews};
}

final photoUploadsProvider =
    NotifierProvider<PhotoUploadsNotifier, Map<String, List<Uint8List>>>(
      PhotoUploadsNotifier.new,
    );
