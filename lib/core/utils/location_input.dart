import 'plus_code.dart';

/// Search text that names a location directly (a Google Maps link,
/// coordinates or a plus code) instead of a query to search for. Recognising
/// it here skips the paid Places autocomplete.
sealed class LocationInput {
  const LocationInput();
}

/// A point known from the text alone.
class PointInput extends LocationInput {
  const PointInput(this.latitude, this.longitude, this.source, {this.name});

  final double latitude;
  final double longitude;
  final LocationSource source;

  /// Place name, when a Maps link carries one.
  final String? name;
}

/// A `maps.app.goo.gl` / `goo.gl/maps` link; following its redirect gives the
/// full link with the coordinates.
class ShortLinkInput extends LocationInput {
  const ShortLinkInput(this.url);
  final Uri url;
}

/// A Maps link that names a place but has no coordinates in it.
class LinkQueryInput extends LocationInput {
  const LinkQueryInput(this.query);
  final String query;
}

/// A plus code missing its leading digits (`WJ8P+2V Kochi`), placed near
/// [locality] or the user.
class ShortPlusCodeInput extends LocationInput {
  const ShortPlusCodeInput(this.code, {this.locality});
  final String code;
  final String? locality;
}

enum LocationSource {
  coordinates('Coordinates'),
  mapsLink('Google Maps link'),
  plusCode('Plus code');

  const LocationSource(this.label);
  final String label;
}

/// Reads [text] as a direct location, or null when it's an ordinary search.
LocationInput? parseLocationInput(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;

  // Shared text is often "Place name https://maps.app.goo.gl/…".
  final link = RegExp(r'https?://\S+').firstMatch(t)?.group(0);
  if (link != null) return _parseLink(link);

  return _parseCoordinates(t) ?? _parsePlusCode(t);
}

/// Reads a full Google Maps URL (also used on a resolved short link).
LocationInput? parseMapsUrl(String url) => _parseLink(url);

LocationInput? _parseLink(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();

  if (host == 'maps.app.goo.gl' ||
      (host == 'goo.gl' && uri.path.startsWith('/maps'))) {
    return ShortLinkInput(uri);
  }
  final isMaps =
      host.startsWith('maps.google.') ||
      (host.contains('google.') && uri.path.startsWith('/maps'));
  if (!isMaps) return null;

  final decoded = Uri.decodeFull(raw).replaceAll('+', ' ');
  final name = _placeName(uri);

  // `!3d…!4d…` is the place itself; `@lat,lng` is only where the map was
  // looking, so it comes last.
  final pin = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)').firstMatch(decoded);
  if (pin != null) return _point(pin.group(1)!, pin.group(2)!, name);

  for (final key in ['q', 'query', 'll', 'destination', 'center']) {
    final value = uri.queryParameters[key];
    if (value == null || value.isEmpty) continue;
    if (_parseCoordinates(value) case final PointInput p) {
      return PointInput(
        p.latitude,
        p.longitude,
        LocationSource.mapsLink,
        name: name,
      );
    }
    if (_parsePlusCode(value) case final code?) return code;
    if (key == 'q' || key == 'query') return LinkQueryInput(value);
  }

  // /maps/search/9.93,+76.26 and /maps/place/9.93,76.26
  for (final segment in uri.pathSegments) {
    if (_parseCoordinates(segment.replaceAll('+', ' '))
        case final PointInput p) {
      return PointInput(p.latitude, p.longitude, LocationSource.mapsLink);
    }
  }

  final view = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(decoded);
  if (view != null) return _point(view.group(1)!, view.group(2)!, name);

  return name != null ? LinkQueryInput(name) : null;
}

String? _placeName(Uri uri) {
  final i = uri.pathSegments.indexOf('place');
  if (i < 0 || i + 1 >= uri.pathSegments.length) return null;
  final name = uri.pathSegments[i + 1].replaceAll('+', ' ').trim();
  if (name.isEmpty || name.startsWith('@')) return null;
  // A dropped pin's "name" is just its coordinates.
  return _parseCoordinates(name) == null ? name : null;
}

PointInput? _point(String lat, String lng, String? name) {
  final la = double.tryParse(lat);
  final ln = double.tryParse(lng);
  if (la == null || ln == null || !_inRange(la, ln)) return null;
  return PointInput(la, ln, LocationSource.mapsLink, name: name);
}

final _decimal = RegExp(
  r'^\(?\s*(-?\d{1,2}(?:\.\d+)?)\s*°?\s*([NSns])?\s*[,;\s]\s*'
  r'(-?\d{1,3}(?:\.\d+)?)\s*°?\s*([EWew])?\s*\)?$',
);

final _dms = RegExp(
  r'''(\d{1,3})\s*°\s*(?:(\d{1,2}(?:\.\d+)?)\s*['′])?\s*(?:(\d{1,2}(?:\.\d+)?)\s*["″])?\s*([NSEWnsew])''',
);

PointInput? _parseCoordinates(String text) {
  final t = text.trim();

  final d = _decimal.firstMatch(t);
  if (d != null) {
    final hasHemisphere = d.group(2) != null || d.group(4) != null;
    // Plain "12 34" is more likely an address than a point; real
    // coordinates carry decimals or N/E letters.
    if (!hasHemisphere &&
        !(d.group(1)!.contains('.') && d.group(3)!.contains('.'))) {
      return null;
    }
    var lat = double.parse(d.group(1)!);
    var lng = double.parse(d.group(3)!);
    if (d.group(2)?.toUpperCase() == 'S') lat = -lat.abs();
    if (d.group(4)?.toUpperCase() == 'W') lng = -lng.abs();
    return _inRange(lat, lng)
        ? PointInput(lat, lng, LocationSource.coordinates)
        : null;
  }

  // 9°55'52.3"N 76°16'02.3"E, as Google Maps shows a dropped pin.
  final parts = _dms.allMatches(t).toList();
  if (parts.length == 2) {
    double? lat;
    double? lng;
    for (final m in parts) {
      final value =
          double.parse(m.group(1)!) +
          (double.tryParse(m.group(2) ?? '') ?? 0) / 60 +
          (double.tryParse(m.group(3) ?? '') ?? 0) / 3600;
      switch (m.group(4)!.toUpperCase()) {
        case 'N':
          lat = value;
        case 'S':
          lat = -value;
        case 'E':
          lng = value;
        case 'W':
          lng = -value;
      }
    }
    if (lat != null && lng != null && _inRange(lat, lng)) {
      return PointInput(lat, lng, LocationSource.coordinates);
    }
  }
  return null;
}

final _plusCode = RegExp(
  r'(?:^|\s)([23456789CFGHJMPQRVWX]{2,8}0*\+[23456789CFGHJMPQRVWX]{0,7})(?=$|[\s,])',
  caseSensitive: false,
);

LocationInput? _parsePlusCode(String text) {
  final m = _plusCode.firstMatch(text);
  if (m == null) return null;
  final code = m.group(1)!.toUpperCase();
  if (!PlusCode.isValid(code)) return null;
  if (PlusCode.isFull(code)) {
    final (lat, lng) = PlusCode.decode(code);
    return PointInput(lat, lng, LocationSource.plusCode);
  }
  // "WJ8P+2V Kochi, Kerala": the rest names the area.
  final locality = text
      .replaceRange(m.start, m.end, ' ')
      .replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '')
      .trim();
  return ShortPlusCodeInput(code, locality: locality.isEmpty ? null : locality);
}

bool _inRange(double lat, double lng) =>
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
