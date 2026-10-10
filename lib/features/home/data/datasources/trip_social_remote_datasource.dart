import '../../../../core/network/supabase_api.dart';

/// Likes, saves and follows of the signed-in user. Each call is idempotent,
/// so a double tap or a retry can't fail on a duplicate.
class TripSocialRemoteDatasource {
  Future<void> setLiked(String tripId, bool liked) =>
      _toggle('trip_likes', {'trip_id': tripId}, on: liked);

  Future<void> setSaved(String tripId, bool saved) =>
      _toggle('trip_saves', {'trip_id': tripId}, on: saved);

  Future<void> setFollowing(String authorId, bool following) => _toggle(
    'follows',
    {'following_id': authorId},
    on: following,
    userColumn: 'follower_id',
  );

  Future<void> _toggle(
    String table,
    Map<String, Object> key, {
    required bool on,
    String userColumn = 'user_id',
  }) => SupabaseApi.run((client) async {
    final row = {userColumn: SupabaseApi.requireUserId, ...key};
    if (on) {
      await client.from(table).upsert(row, ignoreDuplicates: true);
    } else {
      await client.from(table).delete().match(row);
    }
  });
}
