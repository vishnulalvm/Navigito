import 'package:flutter_test/flutter_test.dart';
import 'package:navigito/features/trip_detail/domain/entities/trip_stop.dart';
import 'package:navigito/features/trip_detail/presentation/widgets/google_maps_sheet.dart';

TripStop _stop(int i, {String? placeId}) => TripStop(
  id: '$i',
  day: 1,
  time: '',
  title: 'Stop $i',
  type: StopType.attraction,
  latitude: 10.0 + i,
  longitude: 76.0 + i,
  placeId: placeId,
);

void main() {
  test('a single place opens as a pin with its Google place', () {
    final uri = TripMapsLinks.place(_stop(1, placeId: 'abc'));
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['query'], '11.0,77.0');
    expect(uri.queryParameters['query_place_id'], 'abc');
  });

  test('a pin without a place id leaves it out', () {
    final uri = TripMapsLinks.place(_stop(1));
    expect(uri.queryParameters.containsKey('query_place_id'), isFalse);
  });

  test('the route runs from the first stop to the last through the rest', () {
    final uri = TripMapsLinks.route([_stop(0), _stop(1), _stop(2), _stop(3)]);
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['origin'], '10.0,76.0');
    expect(uri.queryParameters['destination'], '13.0,79.0');
    expect(uri.queryParameters['waypoints'], '11.0,77.0|12.0,78.0');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('long routes keep at most the Google Maps waypoint limit, in order', () {
    final stops = [for (var i = 0; i < 30; i++) _stop(i)];
    final uri = TripMapsLinks.route(stops);
    final waypoints = uri.queryParameters['waypoints']!.split('|');
    expect(waypoints, hasLength(TripMapsLinks.maxWaypoints));
    final lats = [for (final w in waypoints) double.parse(w.split(',')[0])];
    expect(lats, orderedEquals([...lats]..sort()));
    expect(uri.queryParameters['destination'], '39.0,105.0');
  });

  test('start journey navigates from here through every stop to the last', () {
    final uri = TripMapsLinks.navigate([_stop(0), _stop(1), _stop(2)]);
    expect(uri.queryParameters.containsKey('origin'), isFalse);
    expect(uri.queryParameters['waypoints'], '10.0,76.0|11.0,77.0');
    expect(uri.queryParameters['destination'], '12.0,78.0');
    expect(uri.queryParameters['dir_action'], 'navigate');
  });
}
