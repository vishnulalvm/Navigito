import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers where the home map was last looking, so the next launch can
/// open there straight away instead of waiting for a GPS fix.
class MapCameraCache {
  MapCameraCache(this._prefs);
  final SharedPreferences _prefs;

  static const _latKey = 'map_camera_lat';
  static const _lngKey = 'map_camera_lng';
  static const _zoomKey = 'map_camera_zoom';

  CameraPosition? read() {
    final lat = _prefs.getDouble(_latKey);
    final lng = _prefs.getDouble(_lngKey);
    final zoom = _prefs.getDouble(_zoomKey);
    if (lat == null || lng == null || zoom == null) return null;
    return CameraPosition(target: LatLng(lat, lng), zoom: zoom);
  }

  Future<void> write(CameraPosition camera) => Future.wait([
    _prefs.setDouble(_latKey, camera.target.latitude),
    _prefs.setDouble(_lngKey, camera.target.longitude),
    _prefs.setDouble(_zoomKey, camera.zoom),
  ]);
}
