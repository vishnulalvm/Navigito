import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/snackbar.dart';
import '../../domain/entities/trip_detail.dart';

/// Link that opens [tripId] in the app, e.g. `navigito://open/trip/<id>`.
/// The path is the app's own route, so the router handles it as is.
Uri tripLink(String tripId) =>
    Uri(scheme: 'navigito', host: 'open', path: AppRouter.tripDetail(tripId));

/// Private trips open only for their author; a link would be a dead end.
bool _canShare(BuildContext context, TripDetail trip) {
  if (trip.isPublic) return true;
  showErrorSnack(context, 'This trip is private. Make it public to share it.');
  return false;
}

Future<void> shareTrip(BuildContext context, TripDetail trip) async {
  if (!_canShare(context, trip)) return;
  final summary = [
    '${trip.days} ${trip.days == 1 ? 'day' : 'days'}',
    '${trip.stopCount} ${trip.stopCount == 1 ? 'stop' : 'stops'}',
    if (trip.distanceKm > 0) '${trip.distanceKm} km',
  ].join(' · ');
  // On iPad the share sheet anchors to the tapped button.
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      subject: trip.title,
      text:
          '${trip.title} by ${trip.authorName}\n$summary\n\n'
          'Open it in Navigito: ${tripLink(trip.id)}',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

Future<void> copyTripLink(BuildContext context, TripDetail trip) async {
  if (!_canShare(context, trip)) return;
  await Clipboard.setData(ClipboardData(text: '${tripLink(trip.id)}'));
  if (context.mounted) showErrorSnack(context, 'Link copied');
}
