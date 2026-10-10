import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/widgets/auth_gate.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/main_shell/presentation/pages/main_shell_page.dart';
import '../../features/my_trips/presentation/pages/my_trips_page.dart';
import '../../features/add_trip/presentation/pages/add_trip_details_page.dart';
import '../../features/add_trip/presentation/pages/add_trip_page.dart';
import '../../features/add_trip/presentation/pages/add_trip_timeline_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/trip_detail/presentation/pages/trip_detail_page.dart';

abstract final class AppRouter {
  static const home = '/';
  static const myTrips = '/my-trips';
  static const addTrip = '/add-trip';
  static const addTripTimeline = '/add-trip/timeline';
  static const addTripDetails = '/add-trip/details';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static String tripDetail(String id) => '/trip/$id';

  static final router = GoRouter(
    initialLocation: home,
    routes: [
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
                builder: (context, state) => const AuthGate(
                  title: 'Your trips live here',
                  message:
                      'Sign in to see your saved, created and liked trips.',
                  icon: Icons.map_outlined,
                  child: MyTripsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: notifications,
                builder: (context, state) => const AuthGate(
                  title: 'Stay in the loop',
                  message: 'Sign in to see likes, comments and new followers.',
                  icon: Icons.notifications_none,
                  child: NotificationsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: profile,
                builder: (context, state) => const AuthGate(
                  title: 'Welcome to Navigito',
                  message:
                      'Sign in to build your profile and share trips with other travellers.',
                  icon: Icons.person_outline,
                  child: ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Full-screen flow; the navbar's Add Trip tab opens it. Slides up like
      // a sheet, and the draft survives closing it.
      GoRoute(
        path: addTrip,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthGate(
            title: 'Share your journey',
            message: 'Sign in to create and publish your own trips.',
            icon: Icons.add_location_alt_outlined,
            child: AddTripPage(),
          ),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: 'timeline',
            builder: (context, state) => const AddTripTimelinePage(),
          ),
          GoRoute(
            path: 'details',
            builder: (context, state) => const AddTripDetailsPage(),
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
