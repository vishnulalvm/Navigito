import 'package:flutter/material.dart';

import '../../../trip_detail/domain/entities/trip_stop.dart';

class DraftStop {
  const DraftStop({
    required this.name,
    required this.type,
    required this.day,
    required this.time,
  });

  final String name;
  final StopType type;
  final int day;
  final TimeOfDay time;

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
