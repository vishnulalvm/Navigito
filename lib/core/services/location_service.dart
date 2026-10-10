import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns null when permission is denied or services are disabled.
  ///
  /// A fresh fix can take many seconds indoors, so it is capped and falls back
  /// to the last known position.
  Future<Position?> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }
}
