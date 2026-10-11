import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/snackbar.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/entities/trip_stop.dart';

/// Google Maps links (Maps URLs, no API key) for a trip's stops.
abstract final class TripMapsLinks {
  /// Most stops in between that the Google Maps app takes in one route.
  static const maxWaypoints = 9;

  static String _latLng(TripStop s) => '${s.latitude},${s.longitude}';

  /// One stop as a pin, matched to its Google place when it has one.
  static Uri place(TripStop stop) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': _latLng(stop), 'query_place_id': ?stop.placeId},
  );

  /// Driving directions through every stop in order. With more than
  /// [maxWaypoints] in between, keeps that many, evenly spread.
  static Uri route(List<TripStop> stops) {
    final first = stops.first;
    final last = stops.last;
    final middle = _spread(stops.sublist(1, stops.length - 1), maxWaypoints);
    // Place ids only work when every waypoint has one.
    final allPlaces = middle.every((s) => s.placeId != null);
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': _latLng(first),
      'origin_place_id': ?first.placeId,
      'destination': _latLng(last),
      'destination_place_id': ?last.placeId,
      if (middle.isNotEmpty) 'waypoints': middle.map(_latLng).join('|'),
      if (middle.isNotEmpty && allPlaces)
        'waypoint_place_ids': middle.map((s) => s.placeId).join('|'),
      'travelmode': 'driving',
    });
  }

  /// Turn-by-turn navigation from where the user is now, through every stop
  /// (the first included) to the last. Same waypoint limit as [route].
  static Uri navigate(List<TripStop> stops) {
    final last = stops.last;
    final middle = _spread(stops.sublist(0, stops.length - 1), maxWaypoints);
    final allPlaces = middle.every((s) => s.placeId != null);
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': _latLng(last),
      'destination_place_id': ?last.placeId,
      if (middle.isNotEmpty) 'waypoints': middle.map(_latLng).join('|'),
      if (middle.isNotEmpty && allPlaces)
        'waypoint_place_ids': middle.map((s) => s.placeId).join('|'),
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
  }

  /// Turn-by-turn navigation from where the user is now to one stop.
  static Uri navigateTo(TripStop stop) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': _latLng(stop),
        'destination_place_id': ?stop.placeId,
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });

  /// [max] items of [items] spread evenly, keeping their order.
  static List<T> _spread<T>(List<T> items, int max) {
    if (items.length <= max) return items;
    return [
      for (var i = 0; i < max; i++) items[(i * items.length / max).floor()],
    ];
  }
}

/// Opens [uri] in the Google Maps app, or the browser without it.
Future<void> openInGoogleMaps(BuildContext context, Uri uri) async {
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    showErrorSnack(context, 'Could not open Google Maps');
  }
}

/// Choices for opening [trip] in Google Maps.
Future<void> showGoogleMapsSheet(BuildContext context, TripDetail trip) {
  final stops = trip.stops;
  final skipped = stops.length - 2 - TripMapsLinks.maxWaypoints;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;

      Future<void> open(Uri uri) {
        Navigator.pop(sheetContext);
        return openInGoogleMaps(context, uri);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Open in Google Maps',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (stops.length >= 2)
              ListTile(
                leading: Icon(Icons.route_outlined, color: scheme.primary),
                title: const Text('View all stops'),
                subtitle: Text(
                  skipped > 0
                      ? 'Route through ${TripMapsLinks.maxWaypoints + 2} of '
                            '${stops.length} stops (Google Maps limit)'
                      : 'Route through all ${stops.length} stops',
                ),
                onTap: () => open(TripMapsLinks.route(stops)),
              ),
            ListTile(
              leading: Icon(Icons.trip_origin, color: scheme.primary),
              title: Text(
                stops.length >= 2 ? 'View starting point' : 'View location',
              ),
              subtitle: Text(stops.first.title),
              onTap: () => open(TripMapsLinks.place(stops.first)),
            ),
            if (stops.length >= 2)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: scheme.primary),
                title: const Text('View ending point'),
                subtitle: Text(stops.last.title),
                onTap: () => open(TripMapsLinks.place(stops.last)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
