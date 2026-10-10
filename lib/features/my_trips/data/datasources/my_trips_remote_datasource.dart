import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_api.dart';
import '../../../home/data/models/trip_card_model.dart';
import '../../../home/domain/entities/trip.dart';
import '../../domain/repositories/my_trips_repository.dart';

/// The signed-in user's own, saved and liked trips.
class MyTripsRemoteDatasource {
  Future<List<Trip>> trips(MyTripsTab tab) => SupabaseApi.run(
    (client) async =>
        tripsFromCards(await client.rpc('my_trips', params: {'tab': tab.name})),
  );

  /// Stops, likes, saves and comments go with it (cascading deletes).
  Future<void> delete(String tripId) => SupabaseApi.run((client) async {
    // Row security turns deleting someone else's trip into deleting nothing,
    // so check a row actually went.
    final deleted = await client
        .from('trips')
        .delete()
        .eq('id', tripId)
        .select('id');
    if (deleted.isEmpty) {
      throw const ServerException('Could not delete this trip');
    }
  });
}
