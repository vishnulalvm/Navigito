import 'package:flutter/material.dart';

/// Icon for a trip category such as "cultural" or "road trip".
IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('cultur')) return Icons.account_balance_outlined;
  if (c.contains('histor')) return Icons.museum_outlined;
  if (c.contains('nature') || c.contains('outdoor')) {
    return Icons.park_outlined;
  }
  if (c.contains('advent') || c.contains('hik')) return Icons.hiking;
  if (c.contains('beach')) return Icons.beach_access_outlined;
  if (c.contains('food') || c.contains('culinary')) {
    return Icons.restaurant_outlined;
  }
  if (c.contains('city') || c.contains('urban')) {
    return Icons.location_city_outlined;
  }
  if (c.contains('road')) return Icons.directions_car_outlined;
  if (c.contains('relax') || c.contains('wellness')) {
    return Icons.spa_outlined;
  }
  if (c.contains('night')) return Icons.nightlife_outlined;
  if (c.contains('shop')) return Icons.shopping_bag_outlined;
  return Icons.local_offer_outlined;
}

/// "road trip" -> "Road Trip".
String categoryLabel(String category) => category
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Accent colours tag pills cycle through, so neighbours differ.
const tagAccents = [
  Color(0xFFE0711C), // orange
  Color(0xFF7C4DDB), // purple
  Color(0xFFD9466B), // rose
  Color(0xFF2E9E5B), // green
  Color(0xFF2F7BD9), // blue
];
