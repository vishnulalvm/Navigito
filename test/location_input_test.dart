import 'package:flutter_test/flutter_test.dart';
import 'package:navigito/core/utils/location_input.dart';
import 'package:navigito/core/utils/plus_code.dart';

void expectPoint(
  LocationInput? input,
  double lat,
  double lng, {
  LocationSource? source,
  String? name,
}) {
  expect(input, isA<PointInput>());
  final p = input! as PointInput;
  expect(p.latitude, closeTo(lat, 1e-6));
  expect(p.longitude, closeTo(lng, 1e-6));
  if (source != null) expect(p.source, source);
  if (name != null) expect(p.name, name);
}

void main() {
  group('coordinates', () {
    test('decimal pair', () {
      expectPoint(
        parseLocationInput('9.9312, 76.2673'),
        9.9312,
        76.2673,
        source: LocationSource.coordinates,
      );
      expectPoint(parseLocationInput('9.9312 76.2673'), 9.9312, 76.2673);
      expectPoint(parseLocationInput('(-33.86, 151.21)'), -33.86, 151.21);
    });

    test('hemisphere letters', () {
      expectPoint(parseLocationInput('9.93° N, 76.26° E'), 9.93, 76.26);
      expectPoint(parseLocationInput('33.86 S 151.21 E'), -33.86, 151.21);
    });

    test('degrees, minutes, seconds as Google Maps shows a pin', () {
      expectPoint(
        parseLocationInput('9°55\'52.3"N 76°16\'02.3"E'),
        9 + 55 / 60 + 52.3 / 3600,
        76 + 16 / 60 + 2.3 / 3600,
      );
    });

    test('ordinary searches are left alone', () {
      expect(parseLocationInput('Munnar'), isNull);
      expect(parseLocationInput('12 34'), isNull);
      expect(parseLocationInput('91.5, 76.2'), isNull);
    });
  });

  group('Google Maps links', () {
    test('place link prefers the pin over the viewport', () {
      expectPoint(
        parseLocationInput(
          'https://www.google.com/maps/place/Fort+Kochi,+Kerala/'
          '@9.9658,76.2421,15z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0'
          '!8m2!3d9.9663!4d76.2425!16s',
        ),
        9.9663,
        76.2425,
        source: LocationSource.mapsLink,
        name: 'Fort Kochi, Kerala',
      );
    });

    test('query and search links', () {
      expectPoint(
        parseLocationInput('https://maps.google.com/?q=9.93,76.26'),
        9.93,
        76.26,
      );
      expectPoint(
        parseLocationInput('https://www.google.com/maps/search/9.93,+76.26'),
        9.93,
        76.26,
      );
      expectPoint(
        parseLocationInput('https://www.google.com/maps/@10.08,77.06,12z'),
        10.08,
        77.06,
      );
    });

    test('shared text around a short link', () {
      final input = parseLocationInput(
        'Munnar Tea Museum\nhttps://maps.app.goo.gl/AbC123xyz',
      );
      expect(input, isA<ShortLinkInput>());
      expect((input! as ShortLinkInput).url.host, 'maps.app.goo.gl');
    });

    test('a link with only a name falls back to searching it', () {
      final input = parseLocationInput(
        'https://www.google.com/maps?q=Mattancherry+Palace',
      );
      expect(input, isA<LinkQueryInput>());
      expect((input! as LinkQueryInput).query, 'Mattancherry Palace');
    });

    test('other links are not locations', () {
      expect(parseLocationInput('https://example.com/maps/x'), isNull);
    });
  });

  group('plus codes', () {
    test('full code decodes to its cell centre', () {
      // Cell 20.37…20.370125 N, 2.782125…2.78225 E.
      final (lat, lng) = PlusCode.decode('7FG49QCJ+2V');
      expect(lat, closeTo(20.3700625, 1e-7));
      expect(lng, closeTo(2.7821875, 1e-7));
      expectPoint(
        parseLocationInput('7fg49qcj+2v'),
        lat,
        lng,
        source: LocationSource.plusCode,
      );
    });

    test('short code recovers next to a reference', () {
      final full = PlusCode.decode('9C3W9QCJ+2VX');
      final short = PlusCode.recoverNearest('CJ+2VX', 51.3708675, -1.217765625);
      expect(short.$1, closeTo(full.$1, 1e-7));
      expect(short.$2, closeTo(full.$2, 1e-7));
    });

    test('short code keeps the place name after it', () {
      final input = parseLocationInput('WJ8P+2V Kochi, Kerala');
      expect(input, isA<ShortPlusCodeInput>());
      final s = input! as ShortPlusCodeInput;
      expect(s.code, 'WJ8P+2V');
      expect(s.locality, 'Kochi, Kerala');
    });

    test('invalid codes are ignored', () {
      expect(PlusCode.isValid('WJ8+2V'), isFalse);
      expect(PlusCode.isValid('WJ8P+2'), isFalse);
      expect(parseLocationInput('ABCD+EF'), isNull);
    });
  });
}
