import 'package:dio/dio.dart';

import '../../../../core/constants/env.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/polyline_codec.dart';

/// Google Routes API (computeRoutes): driving path through ordered waypoints.
class RoutesRemoteDatasource {
  RoutesRemoteDatasource(this._dio);
  final Dio _dio;

  static const _url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  // Routes API allows at most 25 intermediate waypoints.
  static const _maxIntermediates = 25;

  Map<String, dynamic> _waypoint((double, double) p) => {
    'location': {
      'latLng': {'latitude': p.$1, 'longitude': p.$2},
    },
  };

  Future<List<(double, double)>> roadPath(
    List<(double, double)> waypoints,
  ) async {
    if (Env.routesApiKey.isEmpty) {
      throw const ServerException('ROUTES_API_KEY is not set');
    }
    if (waypoints.length < 2) return waypoints;

    final middle = waypoints.sublist(1, waypoints.length - 1);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _url,
        data: {
          'origin': _waypoint(waypoints.first),
          'destination': _waypoint(waypoints.last),
          if (middle.isNotEmpty)
            'intermediates': [
              for (final p in middle.take(_maxIntermediates)) _waypoint(p),
            ],
          'travelMode': 'DRIVE',
          // Traffic-aware routing bills at the Pro SKU; a trip's shape
          // doesn't need it. (More than 10 intermediates is also Pro.)
          'routingPreference': 'TRAFFIC_UNAWARE',
        },
        options: Options(
          headers: {
            'X-Goog-Api-Key': Env.routesApiKey,
            'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
          },
        ),
      );
      final routes = res.data?['routes'] as List?;
      final encoded =
          routes?.firstOrNull?['polyline']?['encodedPolyline'] as String?;
      if (encoded == null) throw const ServerException('No route found');
      return decodePolyline(encoded);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?.toString() ?? e.message ?? 'Routes request failed',
      );
    }
  }
}
