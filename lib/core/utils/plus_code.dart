import 'dart:math' as math;

/// Decodes Open Location Codes ("plus codes", e.g. `7J4VWJ8P+2V`) locally,
/// so pasting one costs no API call. Follows the reference implementation:
/// https://github.com/google/open-location-code
abstract final class PlusCode {
  static const _alphabet = '23456789CFGHJMPQRVWX';
  static const _separatorPosition = 8;
  static const _pairLength = 10;
  static const _gridRows = 5;
  static const _gridCols = 4;

  static final _pattern = RegExp(
    '^[$_alphabet]{2,8}0*\\+[$_alphabet]{0,7}\$',
    caseSensitive: false,
  );

  /// Whether [code] looks like a full or short plus code.
  static bool isValid(String code) {
    final c = code.toUpperCase();
    if (!_pattern.hasMatch(c)) return false;
    final sep = c.indexOf('+');
    // Digits come in pairs before the separator, and a lone digit after it
    // would be ambiguous.
    return sep.isEven && c.length - sep - 1 != 1;
  }

  /// Full codes carry all 8 digits before the `+`; short ones drop the
  /// leading ones and need a nearby reference point.
  static bool isFull(String code) =>
      isValid(code) && code.indexOf('+') == _separatorPosition;

  /// Centre of a full [code] as (latitude, longitude).
  static (double, double) decode(String code) {
    final digits = code.toUpperCase().replaceAll('+', '').replaceAll('0', '');
    var lat = -90.0;
    var lng = -180.0;
    var latSize = 20.0;
    var lngSize = 20.0;

    final pairs = math.min(digits.length, _pairLength);
    for (var i = 0; i < pairs; i += 2) {
      final res = 20 / math.pow(20, i ~/ 2);
      latSize = lngSize = res;
      lat += _alphabet.indexOf(digits[i]) * res;
      if (i + 1 < pairs) lng += _alphabet.indexOf(digits[i + 1]) * res;
    }
    // Digits past the pairs refine a 5×4 grid inside the last cell.
    for (var i = _pairLength; i < digits.length; i++) {
      latSize /= _gridRows;
      lngSize /= _gridCols;
      final v = _alphabet.indexOf(digits[i]);
      lat += (v ~/ _gridCols) * latSize;
      lng += (v % _gridCols) * lngSize;
    }
    return (
      (lat + latSize / 2).clamp(-90.0, 90.0),
      _normalizeLng(lng + lngSize / 2),
    );
  }

  /// Centre of a short [code] (e.g. `WJ8P+2V`) placed in the cell nearest to
  /// the reference point.
  static (double, double) recoverNearest(
    String code,
    double refLat,
    double refLng,
  ) {
    final c = code.toUpperCase();
    if (isFull(c)) return decode(c);
    final missing = _separatorPosition - c.indexOf('+');
    final resolution = math.pow(20, 2 - missing / 2).toDouble();
    final half = resolution / 2;

    var (lat, lng) = decode(_encodePairs(refLat, refLng, missing) + c);
    // The reference's own cell may be the wrong neighbour near its edges.
    if (refLat + half < lat && lat - resolution >= -90) {
      lat -= resolution;
    } else if (refLat - half > lat && lat + resolution <= 90) {
      lat += resolution;
    }
    if (refLng + half < lng) {
      lng -= resolution;
    } else if (refLng - half > lng) {
      lng += resolution;
    }
    return (lat, _normalizeLng(lng));
  }

  /// The first [length] pair digits for a point.
  static String _encodePairs(double lat, double lng, int length) {
    var la = lat.clamp(-90.0, 90.0) + 90;
    var ln = _normalizeLng(lng) + 180;
    final out = StringBuffer();
    for (var i = 0; i < length ~/ 2; i++) {
      final res = 20 / math.pow(20, i);
      final dLat = math.min((la / res).floor(), 19);
      final dLng = math.min((ln / res).floor(), 19);
      out
        ..write(_alphabet[dLat])
        ..write(_alphabet[dLng]);
      la -= dLat * res;
      ln -= dLng * res;
    }
    return out.toString();
  }

  static double _normalizeLng(double lng) {
    var l = lng;
    while (l < -180) {
      l += 360;
    }
    while (l >= 180) {
      l -= 360;
    }
    return l;
  }
}
