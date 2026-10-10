import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const kPreviewMarkerId = MarkerId('preview');

/// Azure pin for a location that's shown but not picked yet: a dropped pin
/// or typed coordinates.
Marker previewMarker(LatLng position, {String title = 'Dropped pin'}) => Marker(
  markerId: kPreviewMarkerId,
  position: position,
  zIndexInt: 2,
  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
  infoWindow: InfoWindow(title: title, snippet: formatLatLng(position)),
);

String formatLatLng(LatLng p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

/// Card for a pin dropped on the map, with one action for it.
class DroppedPinCard extends StatelessWidget {
  const DroppedPinCard({
    super.key,
    required this.position,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
  });

  final LatLng position;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pin_drop_outlined,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dropped pin',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatLatLng(position),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove pin',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
