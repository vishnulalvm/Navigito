import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Starts the native Maps SDK before any map is built, so the first map
/// doesn't pay for SDK setup (the main cause of the slow, black first frame).
Future<void> initMapSdk() async {
  final maps = GoogleMapsFlutterPlatform.instance;
  if (maps is! GoogleMapsFlutterAndroid) return;
  try {
    await maps.initializeWithRenderer(AndroidMapRenderer.latest);
  } on PlatformException {
    // Already initialized (e.g. after a hot restart); only allowed once.
  }
  unawaited(maps.warmup());
}
