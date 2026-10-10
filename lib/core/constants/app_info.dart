import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppInfo {
  static const name = 'Navigito';
  static const tagline = 'Discover and share road trips, stop by stop.';

  /// Support and privacy contact shown in the Privacy Policy, Terms and
  /// About. Both app stores require one.
  ///
  /// TODO(release): set before publishing. Until then, debug builds flag it
  /// on the legal screens.
  static const contactEmail = '';

  /// When the Privacy Policy and Terms last changed; update with the text.
  static const legalUpdated = '11 October 2026';

  static bool get hasContact => contactEmail.isNotEmpty;
}

/// "1.0.0 (1)", from the installed app.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});
