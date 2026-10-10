import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../home/presentation/providers/home_providers.dart';

/// Shows the splash on top of the app while the home screen (and its Google
/// Map) loads underneath. Because the real map is created during the splash,
/// it is already drawn when the splash fades away.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _minDuration = Duration(milliseconds: 1500);
  static const _maxWait = Duration(seconds: 8);
  static const _fadeDuration = Duration(milliseconds: 400);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  bool _fading = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  /// Waits for location, marker icons, trips and the map's first frame.
  Future<void> _preload() async {
    final mapReady = Completer<void>();
    ref.listenManual<bool>(mapReadyProvider, (_, ready) {
      if (ready && !mapReady.isCompleted) mapReady.complete();
    }, fireImmediately: true);

    final loading = Future.wait<Object?>([
      ref.read(currentPositionProvider.future),
      ref.read(placeMarkersProvider.future),
      ref.read(tripsProvider.future),
      mapReady.future,
    ]).timeout(_maxWait, onTimeout: () => const []).catchError((_) => const []);

    await Future.wait([loading, Future<void>.delayed(_minDuration)]);
    if (!mounted) return;
    setState(() => _fading = true);
    await Future<void>.delayed(_fadeDuration);
    if (mounted) setState(() => _gone = true);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: widget.child),
        if (!_gone)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fading,
              child: AnimatedOpacity(
                opacity: _fading ? 0 : 1,
                duration: _fadeDuration,
                child: _SplashContent(animation: _intro),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final scale = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));

    return Material(
      color: scheme.primary,
      child: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.explore, size: 56, color: scheme.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
