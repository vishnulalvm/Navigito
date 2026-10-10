import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_api.dart';
import '../../domain/entities/trip_detail.dart';
import '../models/trip_detail_model.dart';

/// A trip with its author, stops and the caller's like/save/follow state,
/// in one call to the `trip_detail` function.
class TripDetailRemoteDatasource {
  Future<TripDetail> detail(String id) => SupabaseApi.run((client) async {
    final json = await client.rpc('trip_detail', params: {'trip_id': id});
    if (json == null) {
      throw const ServerException('This trip is private or was deleted');
    }
    return tripDetailFromJson(json as Map<String, dynamic>);
  });
}
