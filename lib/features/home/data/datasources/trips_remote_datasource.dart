import '../../../../core/network/supabase_api.dart';
import '../../domain/entities/trip.dart';
import '../models/trip_card_model.dart';

/// Public trips for the home sheet, from the `feed_trips` function.
class TripsRemoteDatasource {
  /// Ranked by distance from [latitude]/[longitude] when given; with
  /// [withinMeters], only trips passing that close.
  Future<List<Trip>> feed({
    double? latitude,
    double? longitude,
    int? withinMeters,
  }) => SupabaseApi.run(
    (client) async => tripsFromCards(
      await client.rpc(
        'feed_trips',
        params: {
          'lat': ?latitude,
          'lng': ?longitude,
          'within_m': ?withinMeters,
        },
      ),
    ),
  );
}
