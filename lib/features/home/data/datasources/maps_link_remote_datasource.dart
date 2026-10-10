import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';

/// Expands Google Maps short links (`maps.app.goo.gl/…`) by following their
/// redirects. A plain HTTP request, not a Places API call, so it's free.
class MapsLinkRemoteDatasource {
  MapsLinkRemoteDatasource(this._dio);
  final Dio _dio;

  static const _maxHops = 6;
  final _cache = <String, String>{};

  /// The full Google Maps URL [url] points to.
  Future<String> resolve(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;

    var current = Uri.parse(url);
    try {
      for (var hop = 0; hop < _maxHops; hop++) {
        // EU consent interstitials carry the real target in `continue`.
        if (current.host.startsWith('consent.')) {
          final next = current.queryParameters['continue'];
          if (next == null) break;
          current = Uri.parse(next);
          continue;
        }
        if (!_isShortLink(current)) break;
        // GET rather than HEAD: some redirectors refuse HEAD. The redirect
        // response itself is tiny.
        final res = await _dio.getUri<String>(
          current,
          options: Options(
            followRedirects: false,
            responseType: ResponseType.plain,
            validateStatus: (s) => s != null && s < 400,
          ),
        );
        final location = res.headers.value('location');
        if (location == null) break;
        current = current.resolve(location);
      }
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Could not open the link');
    }
    if (_isShortLink(current)) {
      throw const ServerException('Could not open the link');
    }
    return _cache[url] = current.toString();
  }

  static bool _isShortLink(Uri uri) =>
      uri.host == 'maps.app.goo.gl' || uri.host == 'goo.gl';
}
