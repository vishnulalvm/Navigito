import 'dart:math';

import 'package:flutter/material.dart';

/// Looping splash motion graphic: a stylised map where an origin point is
/// picked, a route is traced to a destination pin that drops in, and a
/// traveller runs along it before the scene resets.
class SplashRouteAnimation extends StatefulWidget {
  const SplashRouteAnimation({
    super.key,
    required this.background,
    required this.foreground,
    this.size = 220,
  });

  final Color background;
  final Color foreground;
  final double size;

  @override
  State<SplashRouteAnimation> createState() => _SplashRouteAnimationState();
}

class _SplashRouteAnimationState extends State<SplashRouteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _RoutePainter(
          progress: _loop,
          background: widget.background,
          foreground: widget.foreground,
        ),
      ),
    );
  }
}

/// Progress of [t] through the window [begin]..[end], clamped to 0..1.
double _interval(double t, double begin, double end) =>
    ((t - begin) / (end - begin)).clamp(0.0, 1.0);

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.progress,
    required this.background,
    required this.foreground,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color background;
  final Color foreground;

  // Normalised map layout. The route only runs along the major roads.
  static const _majorRoads = [
    [Offset(-0.1, 0.30), Offset(1.1, 0.30)],
    [Offset(-0.1, 0.52), Offset(1.1, 0.52)],
    [Offset(-0.1, 0.74), Offset(1.1, 0.74)],
    [Offset(0.24, -0.1), Offset(0.24, 1.1)],
    [Offset(0.52, -0.1), Offset(0.52, 1.1)],
    [Offset(0.76, -0.1), Offset(0.76, 1.1)],
  ];
  static const _minorRoads = [
    [Offset(-0.1, 0.12), Offset(1.1, 0.12)],
    [Offset(-0.1, 0.89), Offset(1.1, 0.89)],
    [Offset(0.38, -0.1), Offset(0.38, 1.1)],
    [Offset(0.64, -0.1), Offset(0.64, 1.1)],
    [Offset(0.08, -0.1), Offset(0.08, 1.1)],
    [Offset(0.92, -0.1), Offset(0.92, 1.1)],
    [Offset(0.0, 0.18), Offset(0.85, 1.05)],
  ];
  static const _route = [
    Offset(0.24, 0.74),
    Offset(0.24, 0.52),
    Offset(0.52, 0.52),
    Offset(0.52, 0.30),
    Offset(0.76, 0.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final s = size.width;
    Offset p(Offset n) => Offset(n.dx * s, n.dy * s);

    final bounds = Offset.zero & size;
    final center = bounds.center;
    final radius = s / 2;

    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));

    // Map base and roads.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = foreground.withValues(alpha: 0.06),
    );
    final minor = Paint()
      ..color = foreground.withValues(alpha: 0.08)
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;
    for (final r in _minorRoads) {
      canvas.drawLine(p(r[0]), p(r[1]), minor);
    }
    final major = Paint()
      ..color = foreground.withValues(alpha: 0.14)
      ..strokeWidth = s * 0.034
      ..strokeCap = StrokeCap.round;
    for (final r in _majorRoads) {
      canvas.drawLine(p(r[0]), p(r[1]), major);
    }

    // Soft vignette so the map melts into the splash background.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [background.withValues(alpha: 0), background],
          stops: const [0.62, 1],
        ).createShader(bounds),
    );

    // Everything below resets each loop, so fade it out at the end.
    final loopFade = 1 - _interval(t, 0.9, 1);
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: loopFade),
    );

    final origin = p(_route.first);
    final destination = p(_route.last);
    final routePath = _roundedPath(_route.map(p).toList(), s * 0.06);
    final metric = routePath.computeMetrics().first;

    // 1. Origin is picked: pops in and pulses while the route is searched.
    final pick = Curves.easeOutBack.transform(_interval(t, 0.02, 0.14));
    final pulseFade = _interval(t, 0.04, 0.1) * (1 - _interval(t, 0.45, 0.55));
    for (var i = 0; i < 2; i++) {
      final ripple = (t * 3 + i / 2) % 1;
      _ring(
        canvas,
        origin,
        s * (0.03 + 0.08 * ripple),
        foreground.withValues(alpha: 0.5 * (1 - ripple) * pulseFade),
        s * 0.008,
      );
    }

    // 2. Route is traced from the origin to the destination.
    final draw = Curves.easeInOutCubic.transform(_interval(t, 0.14, 0.56));
    if (draw > 0) {
      final traced = metric.extractPath(0, metric.length * draw);
      canvas.drawPath(
        traced,
        Paint()
          ..color = foreground.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        traced,
        Paint()
          ..color = foreground
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.022
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (draw < 1) {
        final head = metric.getTangentForOffset(metric.length * draw)!.position;
        canvas.drawCircle(
          head,
          s * 0.04,
          Paint()
            ..color = foreground.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(head, s * 0.018, Paint()..color = foreground);
      }
    }

    // Origin marker, drawn over the start of the route.
    if (pick > 0) {
      canvas.drawCircle(origin, s * 0.034 * pick, Paint()..color = foreground);
      canvas.drawCircle(origin, s * 0.016 * pick, Paint()..color = background);
    }

    // 3. Destination pin drops in and settles with a ripple.
    final drop = _interval(t, 0.5, 0.66);
    if (drop > 0) {
      final land = Curves.bounceOut.transform(drop);
      final settle = _interval(t, 0.62, 0.88);
      if (settle > 0 && settle < 1) {
        _ring(
          canvas,
          destination,
          s * (0.02 + 0.1 * settle),
          foreground.withValues(alpha: 0.6 * (1 - settle)),
          s * 0.008,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: destination,
          width: s * 0.07 * land,
          height: s * 0.022 * land,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.25 * land),
      );
      final tip = destination.translate(0, -(1 - land) * s * 0.28);
      final pinOpacity = _interval(t, 0.5, 0.54);
      final pinRadius = s * 0.046;
      canvas.drawPath(
        _pin(tip, pinRadius),
        Paint()..color = foreground.withValues(alpha: pinOpacity),
      );
      canvas.drawCircle(
        tip.translate(0, -pinRadius * 2.2),
        pinRadius * 0.42,
        Paint()..color = background.withValues(alpha: pinOpacity),
      );
    }

    // 4. A traveller runs the found route.
    final travel = Curves.easeInOut.transform(_interval(t, 0.64, 0.9));
    if (travel > 0 && travel < 1) {
      final at = metric.getTangentForOffset(metric.length * travel)!.position;
      canvas.drawCircle(
        at,
        s * 0.045,
        Paint()
          ..color = foreground.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(at, s * 0.026, Paint()..color = foreground);
      canvas.drawCircle(at, s * 0.013, Paint()..color = background);
    }

    canvas.restore(); // loop fade layer
    canvas.restore(); // circular clip

    // Thin lens edge.
    _ring(
      canvas,
      center,
      radius - 1,
      foreground.withValues(alpha: 0.18),
      1.5,
    );
  }

  void _ring(Canvas c, Offset at, double r, Color color, double width) {
    c.drawCircle(
      at,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  /// Polyline through [points] with corners rounded by [corner].
  Path _roundedPath(List<Offset> points, double corner) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1], curr = points[i], next = points[i + 1];
      final inDir = curr - prev, outDir = next - curr;
      final r = min(corner, min(inDir.distance, outDir.distance) / 2);
      final a = curr - inDir / inDir.distance * r;
      final b = curr + outDir / outDir.distance * r;
      path
        ..lineTo(a.dx, a.dy)
        ..quadraticBezierTo(curr.dx, curr.dy, b.dx, b.dy);
    }
    return path..lineTo(points.last.dx, points.last.dy);
  }

  /// Teardrop map pin whose point sits at [tip].
  Path _pin(Offset tip, double r) {
    final c = tip.translate(0, -r * 2.2);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(c.dx - r * 1.05, c.dy + r, c.dx - r, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), pi, pi, false)
      ..quadraticBezierTo(c.dx + r * 1.05, c.dy + r, tip.dx, tip.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.background != background || old.foreground != foreground;
}
