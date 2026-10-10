import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_api.dart';
import '../../domain/entities/new_trip.dart';

/// Creates a trip and its stops in one transaction (`create_trip`), and
/// stores stop photos in the public `trip-photos` bucket.
class AddTripRemoteDatasource {
  static const _bucket = 'trip-photos';
  static final _random = Random.secure();

  /// Files go under the user's own folder, as the bucket's policy requires,
  /// with a random name so they never clash. They never change, so devices
  /// and the CDN may cache them for a year.
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) => SupabaseApi.run((client) async {
    final name = List.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    final path = '${SupabaseApi.requireUserId}/$name.$ext';
    final bucket = client.storage.from(_bucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        cacheControl: '31536000',
      ),
    );
    return bucket.getPublicUrl(path);
  });

  Future<void> deletePhoto(String url) => SupabaseApi.run((client) async {
    final marker = '/object/public/$_bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return;
    await client.storage.from(_bucket).remove([
      url.substring(i + marker.length),
    ]);
  });

  Future<String> create(NewTrip trip) => SupabaseApi.run((client) async {
    final id = await client.rpc(
      'create_trip',
      params: {
        'trip': {
          'title': trip.title,
          'description': trip.description,
          'days': trip.days,
          'tags': trip.tags,
          'is_public': trip.isPublic,
        },
        'stops': [
          for (final s in trip.stops)
            {
              'day': s.day,
              'time': s.time,
              'title': s.title,
              'subtitle': s.subtitle,
              'type': s.type.name,
              'latitude': s.latitude,
              'longitude': s.longitude,
              'place_id': ?s.placeId,
              'photo_urls': s.photoUrls,
            },
        ],
      },
    );
    return id as String;
  });
}
