import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/recent_place.dart';

/// Last few picked places, stored on the device.
///
/// Google's terms allow keeping place IDs indefinitely but coordinates for at
/// most 30 days, so older entries are dropped.
class RecentPlacesLocalDatasource {
  RecentPlacesLocalDatasource(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'recent_places';
  static const _max = 5;
  static const _maxAge = Duration(days: 30);

  List<RecentPlace> read() {
    final raw = _prefs.getStringList(_key) ?? const [];
    final cutoff = DateTime.now().subtract(_maxAge);
    final places = <RecentPlace>[];
    for (final s in raw) {
      try {
        final p = RecentPlace.fromJson(jsonDecode(s) as Map<String, dynamic>);
        if (p.savedAt.isAfter(cutoff)) places.add(p);
      } catch (_) {
        // Skip entries from an older, incompatible format.
      }
    }
    return places;
  }

  Future<void> save(RecentPlace place) => _prefs.setStringList(
    _key,
    [
      jsonEncode(place.toJson()),
      for (final p in read())
        if (p.placeId != place.placeId) jsonEncode(p.toJson()),
    ].take(_max).toList(),
  );
}
