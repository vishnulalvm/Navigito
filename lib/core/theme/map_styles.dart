import 'dart:ui';

/// Land colour of each map style, shown over the map until its first frame is
/// drawn so the native view's black surface never shows.
const kLightMapBackground = Color(0xFFF2F2F2);
const kDarkMapBackground = Color(0xFF1D2330);

/// Night style for the Google Map, used in dark mode.
const String kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2330"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8d96a8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2330"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#3a4256"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#1f2e2a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c3446"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3b4660"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f1722"}]}
]
''';
