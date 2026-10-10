import '../../../../core/network/supabase_api.dart';
import '../../domain/entities/feedback.dart';

/// Writes to the `feedback` table, which users can add to but not read.
class FeedbackRemoteDatasource {
  Future<void> send(FeedbackMessage f) => SupabaseApi.run(
    (client) => client.from('feedback').insert({
      'kind': f.kind.name,
      'message': f.message.trim(),
      'app_version': ?f.appVersion,
      'platform': ?f.platform,
    }),
  );
}
