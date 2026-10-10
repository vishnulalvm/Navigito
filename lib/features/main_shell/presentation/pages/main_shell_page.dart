import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/floating_nav_bar.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    NavItem(
      label: 'Explore',
      icon: Icons.location_on_outlined,
      activeIcon: Icons.location_on,
    ),
    NavItem(label: 'My Trips', icon: Icons.map_outlined, activeIcon: Icons.map),
    NavItem(label: 'Add Trip', icon: Icons.add, activeIcon: Icons.add),
    NavItem(
      label: 'Notifications',
      icon: Icons.notifications_none,
      activeIcon: Icons.notifications,
    ),
    NavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              items: _items,
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
