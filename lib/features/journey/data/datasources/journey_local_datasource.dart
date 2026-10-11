import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/journey_progress.dart';

/// One JSON entry per trip in shared preferences.
class JourneyLocalDatasource {
  JourneyLocalDatasource(this._prefs);
  final SharedPreferences _prefs;

  static String _key(String tripId) => 'journey:$tripId';

  JourneyProgress? read(String tripId) {
    final raw = _prefs.getString(_key(tripId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return JourneyProgress(
        tripId: tripId,
        startedAt: DateTime.parse(json['started_at'] as String),
        reachedAt: {
          for (final e in (json['reached'] as Map<String, dynamic>).entries)
            e.key: DateTime.parse(e.value as String),
        },
      );
    } catch (_) {
      // An unreadable entry is as good as none.
      return null;
    }
  }

  Future<void> save(JourneyProgress p) => _prefs.setString(
    _key(p.tripId),
    jsonEncode({
      'started_at': p.startedAt.toIso8601String(),
      'reached': {
        for (final e in p.reachedAt.entries) e.key: e.value.toIso8601String(),
      },
    }),
  );

  Future<void> clear(String tripId) => _prefs.remove(_key(tripId));
}
