import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../../my_trips/presentation/widgets/my_trip_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_stat.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _soon(BuildContext context, String what) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$what coming soon')));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(profileProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final myTrips = ref.watch(myTripsProvider(MyTripsTab.mine));
    final tripsNotifier = ref.read(myTripsProvider(MyTripsTab.mine).notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Could not load profile')),
          data: (p) => ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              FloatingNavBar.reservedSpace(context) + 8,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _soon(context, 'Settings'),
                    icon: const Icon(Icons.settings_outlined),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(52, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: NetworkImage(
                          user?.avatarUrl ?? p.avatarUrl,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? p.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        p.username,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.bio,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          ProfileStat(value: p.trips, label: 'Trips'),
                          ProfileStat(value: p.followers, label: 'Followers'),
                          ProfileStat(value: p.following, label: 'Following'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _soon(context, 'Edit profile'),
                          child: const Text('Edit Profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Trips',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRouter.myTrips),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...myTrips.maybeWhen(
                data: (items) => [
                  for (final t in items.take(2)) ...[
                    MyTripTile(
                      trip: t,
                      onTap: () => context.push(AppRouter.tripDetail(t.id)),
                      onFavorite: () => tripsNotifier.toggleFavorite(t.id),
                      onRemove: () => tripsNotifier.remove(t.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                orElse: () => const [],
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const _ThemeTile(),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: () => _soon(context, 'Help'),
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy',
                      onTap: () => _soon(context, 'Privacy'),
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.logout,
                      label: 'Log out',
                      color: scheme.error,
                      onTap: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('Appearance'),
      subtitle: mode == ThemeMode.system
          ? const Text('Following device')
          : null,
      trailing: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto, size: 18),
            tooltip: 'Auto',
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined, size: 18),
            tooltip: 'Light',
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined, size: 18),
            tooltip: 'Dark',
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) =>
            ref.read(themeModeProvider.notifier).set(s.first),
      ),
    );
  }
}
