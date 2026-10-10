import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Colors.indigo;

  static final _lightScheme = ColorScheme.fromSeed(seedColor: _seed);
  static final _darkScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  );

  /// Pass the wallpaper-based [dynamicScheme] (Android 12+) when available;
  /// otherwise the indigo seed scheme is used.
  static ThemeData light([ColorScheme? dynamicScheme]) =>
      ThemeData(useMaterial3: true, colorScheme: dynamicScheme ?? _lightScheme);

  static ThemeData dark([ColorScheme? dynamicScheme]) =>
      ThemeData(useMaterial3: true, colorScheme: dynamicScheme ?? _darkScheme);
}
