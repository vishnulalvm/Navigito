import 'package:flutter/material.dart';

import '../../domain/entities/trip_stop.dart';

extension StopTypeStyle on StopType {
  IconData get icon => switch (this) {
    StopType.start => Icons.circle,
    StopType.food => Icons.restaurant,
    StopType.attraction => Icons.photo_camera,
    StopType.stay => Icons.hotel,
  };

  Color get color => switch (this) {
    StopType.start => Colors.white,
    StopType.food => const Color(0xFFF57C20),
    StopType.attraction => const Color(0xFF2E9E5B),
    StopType.stay => const Color(0xFF5B7CF0),
  };

  String get label => switch (this) {
    StopType.start => 'Start',
    StopType.food => 'Food',
    StopType.attraction => 'Attractions',
    StopType.stay => 'Stays',
  };
}
