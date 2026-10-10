import 'package:dio/dio.dart';

import '../../../../core/constants/env.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/place_suggestion.dart';

/// Google Places API (New): autocomplete + place location.
///
/// Cost notes:
/// - Requests carry a session token, so typing a query and picking a result is
///   billed as one session instead of per keystroke request.
/// - Field masks keep each call on the cheapest SKU and response small.
/// - Results are kept in memory, so re-typing a query or re-picking a place
///   doesn't call the API again.
class PlacesRemoteDatasource {
  PlacesRemoteDatasource(this._dio);
  final Dio _dio;

  static const _base = 'https://places.googleapis.com/v1';
  static const _maxCachedQueries = 50;

  /// Navigito covers India only.
  static const _regionCodes = ['in'];

  final _suggestionCache = <String, List<PlaceSuggestion>>{};
  final _locationCache = <String, (double, double)>{};

  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? sessionToken,
    double? latitude,
    double? longitude,
  }) async {
    if (Env.placesApiKey.isEmpty) {
      throw const ServerException('PLACES_API_KEY is not set');
    }
    final key = query.trim().toLowerCase();
    final cached = _suggestionCache[key];
    if (cached != null) return cached;

    try {
      final hasLocation = latitude != null && longitude != null;
      final center = {'latitude': latitude, 'longitude': longitude};
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/places:autocomplete',
        data: {
          'input': query,
          'sessionToken': ?sessionToken,
          'includedRegionCodes': _regionCodes,
          'languageCode': 'en',
          if (hasLocation) ...{
            // A preference, not a limit: far destinations still show up.
            'locationBias': {
              'circle': {'center': center, 'radius': 50000.0},
            },
            // Makes each suggestion carry its distance from the user.
            'origin': center,
          },
        },
        options: Options(
          headers: {
            'X-Goog-Api-Key': Env.placesApiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,'
                'suggestions.placePrediction.structuredFormat,'
                'suggestions.placePrediction.distanceMeters,'
                'suggestions.placePrediction.types',
          },
        ),
      );
      final suggestions = (res.data?['suggestions'] as List?) ?? const [];
      final result = [
        for (final s in suggestions)
          if (s['placePrediction'] case final Map<String, dynamic> p)
            _suggestion(p),
      ];
      if (_suggestionCache.length >= _maxCachedQueries) {
        _suggestionCache.remove(_suggestionCache.keys.first);
      }
      return _suggestionCache[key] = result;
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Places request failed');
    }
  }

  PlaceSuggestion _suggestion(Map<String, dynamic> p) {
    final format = p['structuredFormat'] as Map<String, dynamic>? ?? const {};
    final main = format['mainText'] as Map<String, dynamic>? ?? const {};
    final secondary =
        format['secondaryText'] as Map<String, dynamic>? ?? const {};
    final matches = (main['matches'] as List?) ?? const [];
    return PlaceSuggestion(
      placeId: p['placeId'] as String,
      mainText: main['text'] as String? ?? '',
      secondaryText: secondary['text'] as String? ?? '',
      mainMatches: [
        for (final m in matches.cast<Map<String, dynamic>>())
          ((m['startOffset'] as int?) ?? 0, m['endOffset'] as int),
      ],
      distanceMeters: p['distanceMeters'] as int?,
      types: [...?(p['types'] as List?)?.cast<String>()],
    );
  }

  /// Ends the autocomplete session when [sessionToken] is given. Only the
  /// `location` field is requested, which bills as Place Details Essentials.
  Future<(double, double)> location(
    String placeId, {
    String? sessionToken,
  }) async {
    final cached = _locationCache[placeId];
    if (cached != null) return cached;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/places/$placeId',
        queryParameters: {'sessionToken': ?sessionToken},
        options: Options(
          headers: {
            'X-Goog-Api-Key': Env.placesApiKey,
            'X-Goog-FieldMask': 'location',
          },
        ),
      );
      final loc = res.data!['location'] as Map<String, dynamic>;
      return _locationCache[placeId] = (
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      );
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Places request failed');
    }
  }
}
