import 'package:dio/dio.dart';

import '../../../../core/constants/env.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/place_suggestion.dart';

/// Google Places API (New): autocomplete + place location.
class PlacesRemoteDatasource {
  PlacesRemoteDatasource(this._dio);
  final Dio _dio;

  static const _base = 'https://places.googleapis.com/v1';

  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    if (Env.placesApiKey.isEmpty) {
      throw const ServerException('PLACES_API_KEY is not set');
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/places:autocomplete',
        data: {
          'input': query,
          if (latitude != null && longitude != null)
            'locationBias': {
              'circle': {
                'center': {'latitude': latitude, 'longitude': longitude},
                'radius': 50000.0,
              },
            },
        },
        options: Options(headers: {'X-Goog-Api-Key': Env.placesApiKey}),
      );
      final suggestions = (res.data?['suggestions'] as List?) ?? const [];
      return [
        for (final s in suggestions)
          if (s['placePrediction'] != null)
            PlaceSuggestion(
              placeId: s['placePrediction']['placeId'] as String,
              description: s['placePrediction']['text']['text'] as String,
            ),
      ];
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Places request failed');
    }
  }

  Future<(double, double)> location(String placeId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/places/$placeId',
        options: Options(
          headers: {
            'X-Goog-Api-Key': Env.placesApiKey,
            'X-Goog-FieldMask': 'location',
          },
        ),
      );
      final loc = res.data!['location'] as Map<String, dynamic>;
      return (
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      );
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Places request failed');
    }
  }
}
