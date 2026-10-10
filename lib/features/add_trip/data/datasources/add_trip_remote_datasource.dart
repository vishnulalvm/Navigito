import '../../../../core/network/supabase_api.dart';
import '../../domain/entities/new_trip.dart';

/// Creates a trip and its stops in one transaction (`create_trip`).
class AddTripRemoteDatasource {
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
            },
        ],
      },
    );
    return id as String;
  });
}
