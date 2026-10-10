import '../../../../core/constants/env.dart';

/// A photo to show for a stop: one its author uploaded, or a live Google
/// photo of its place.
class PlacePhoto {
  const PlacePhoto.uploaded(String url)
    : _url = url,
      _googleName = null,
      author = null;

  const PlacePhoto.google(String name, {this.author})
    : _googleName = name,
      _url = null;

  final String? _url;

  /// Google photo resource name. Google forbids storing these and they
  /// expire, so they only live in memory for the session.
  final String? _googleName;

  /// Photographer to credit; Google requires it wherever its photo is shown.
  final String? author;

  bool get isGoogle => _googleName != null;

  /// Image URL at about [widthPx] wide. Each load of a Google photo is a
  /// billed request, so ask for the size it's shown at and reuse the URL.
  String url({int widthPx = 800}) =>
      _url ??
      'https://places.googleapis.com/v1/$_googleName/media'
          '?maxWidthPx=$widthPx&key=${Env.placesApiKey}';
}
