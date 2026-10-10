import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_info.dart';
import '../../../../core/router/app_router.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/domain/entities/trip.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';

/// The signed-in traveller and their settings. Trips live on My Trips.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your trips stay saved to your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    final error = await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) showErrorSnack(context, error);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    if (!await _confirmDelete(context) || !context.mounted) return;

    // Blocks the screen: leaving halfway would be confusing.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 20),
              Expanded(child: Text('Deleting your account…')),
            ],
          ),
        ),
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error ?? 'Your account was deleted')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authUserProvider).valueOrNull;

    Widget section(String title, List<Widget> tiles) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (final (i, tile) in tiles.indexed) ...[
                if (i > 0) const Divider(height: 1),
                tile,
              ],
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            FloatingNavBar.reservedSpace(context) + 8,
          ),
          children: [
            Text(
              'Profile',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (user != null) _Header(user: user),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push(AppRouter.addTrip),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add a trip'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 28),
            section('Settings', const [_ThemeTile()]),
            const SizedBox(height: 24),
            section('Support', [
              _LinkTile(
                icon: Icons.feedback_outlined,
                label: 'Send feedback',
                route: AppRouter.feedback,
              ),
              _LinkTile(
                icon: Icons.info_outline,
                label: 'About ${AppInfo.name}',
                route: AppRouter.about,
              ),
            ]),
            const SizedBox(height: 24),
            section('Legal', [
              _LinkTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                route: AppRouter.privacy,
              ),
              _LinkTile(
                icon: Icons.description_outlined,
                label: 'Terms & Conditions',
                route: AppRouter.terms,
              ),
            ]),
            const SizedBox(height: 24),
            section('Account', [
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () => _signOut(context, ref),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text(
                  'Delete account',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text('Removes your trips, photos and activity'),
                onTap: () => _deleteAccount(context, ref),
              ),
            ]),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${AppInfo.name} ${ref.watch(appVersionProvider).valueOrNull ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks the user to type DELETE, since nothing can be recovered afterwards.
Future<bool> _confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    ) ??
    false;

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const _word = 'DELETE';
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = _typed.text.trim().toUpperCase() == _word;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your trips, photos, likes and saves will be deleted for good. '
            'This can\'t be undone.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _typed,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Avatar, name and email, with counts from the user's own trips (shared
/// with the My Trips tab, so no extra request once either has loaded).
class _Header extends ConsumerWidget {
  const _Header({required this.user});

  final AuthUser user;

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K'
      : '$n';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatar = user.avatarUrl ?? '';
    final trips = ref.watch(myTripsProvider(MyTripsTab.mine)).valueOrNull;
    final likes = trips?.fold<int>(0, (sum, Trip t) => sum + t.likes);

    Widget stat(String label, int? value) => Expanded(
      child: Column(
        children: [
          Text(
            value == null ? '–' : _compact(value),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                  onBackgroundImageError: avatar.isEmpty ? null : (_, _) {},
                  child: avatar.isEmpty
                      ? Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user.email case final email?)
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [stat('Trips', trips?.length), stat('Likes', likes)]),
          ],
        ),
      ),
    );
  }
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

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}
