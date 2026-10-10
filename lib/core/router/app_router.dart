import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/main_shell/presentation/pages/main_shell_page.dart';
import '../../features/my_trips/presentation/pages/my_trips_page.dart';
import '../../features/add_trip/presentation/pages/add_trip_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/trip_detail/presentation/pages/trip_detail_page.dart';

abstract final class AppRouter {
  static const splash = '/splash';
  static const home = '/';
  static const myTrips = '/my-trips';
  static const addTrip = '/add-trip';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static String tripDetail(String id) => '/trip/$id';

  static final router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(path: splash, builder: (context, state) => const SplashPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            MainShellPage(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: home,
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const HomePage(),
                  transitionDuration: const Duration(milliseconds: 500),
                  transitionsBuilder: (context, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: myTrips,
                builder: (context, state) => const MyTripsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: addTrip,
                builder: (context, state) => const AddTripPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: notifications,
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      // Outside the shell so the detail screen is full-screen (no navbar).
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) =>
            TripDetailPage(tripId: state.pathParameters['id']!),
      ),
    ],
  );
}
