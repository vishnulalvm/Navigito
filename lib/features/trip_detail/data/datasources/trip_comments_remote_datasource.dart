import '../../../../core/network/supabase_api.dart';
import '../../domain/entities/trip_comment.dart';

/// Comments on a trip, newest first, each with its writer's profile.
class TripCommentsRemoteDatasource {
  static const _columns =
      'id, trip_id, user_id, body, created_at, author:profiles(name, avatar_url)';

  /// Up to [limit] comments older than [before] (or the newest, without it).
  Future<List<TripComment>> page(
    String tripId, {
    DateTime? before,
    int limit = 30,
  }) => SupabaseApi.run((client) async {
    var query = client
        .from('trip_comments')
        .select(_columns)
        .eq('trip_id', tripId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final r in rows) _comment(r)];
  });

  /// Posts as the signed-in user; returns the stored comment.
  Future<TripComment> add(String tripId, String body) =>
      SupabaseApi.run((client) async {
        final row = await client
            .from('trip_comments')
            .insert({
              'trip_id': tripId,
              'user_id': SupabaseApi.requireUserId,
              'body': body,
            })
            .select(_columns)
            .single();
        return _comment(row);
      });

  /// Row security allows this for the comment's writer and the trip's author.
  Future<void> delete(String commentId) => SupabaseApi.run((client) async {
    await client.from('trip_comments').delete().eq('id', commentId);
  });

  TripComment _comment(Map<String, dynamic> r) {
    final author = r['author'] as Map<String, dynamic>? ?? const {};
    return TripComment(
      id: r['id'] as String,
      tripId: r['trip_id'] as String,
      userId: r['user_id'] as String,
      body: r['body'] as String,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      authorName: author['name'] as String? ?? 'Traveller',
      authorAvatarUrl: author['avatar_url'] as String? ?? '',
    );
  }
}
