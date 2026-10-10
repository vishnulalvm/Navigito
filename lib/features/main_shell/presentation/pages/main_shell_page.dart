import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../widgets/floating_nav_bar.dart';

class MainShellPage extends ConsumerWidget {
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

  /// Add Trip opens a full-screen flow rather than a tab, so the tabs after
  /// it sit one branch lower than their nav index.
  static const _addTripIndex = 2;

  static int _branchOf(int navIndex) =>
      navIndex > _addTripIndex ? navIndex - 1 : navIndex;

  static int _navOf(int branch) =>
      branch >= _addTripIndex ? branch + 1 : branch;

  Future<void> _onTap(BuildContext context, WidgetRef ref, int i) async {
    if (i == _addTripIndex) {
      final ok = await ensureSignedIn(
        context,
        ref,
        reason: 'Sign in to create and share trips',
      );
      if (ok && context.mounted) context.push(AppRouter.addTrip);
      return;
    }
    final branch = _branchOf(i);
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // The nav bar stays put under the keyboard. Each tab's own Scaffold
      // still sees the keyboard inset and keeps its fields in view.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              items: _items,
              currentIndex: _navOf(navigationShell.currentIndex),
              onTap: (i) => _onTap(context, ref, i),
            ),
          ),
        ],
      ),
    );
  }
}
