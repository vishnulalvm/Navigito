import 'package:flutter/material.dart';

import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';

/// Stop-type coloured dot with the stop's number, or its type icon.
class StopBadge extends StatelessWidget {
  const StopBadge({super.key, required this.type, this.number, this.size = 28});

  final StopType type;
  final int? number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
      child: number != null
          ? Text(
              '$number',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.46,
              ),
            )
          : Icon(type.icon, size: size * 0.54, color: Colors.white),
    );
  }
}
