import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// "Continue with Apple" on iOS, "Continue with Google" on Android.
class SocialSignInButton extends ConsumerWidget {
  const SocialSignInButton({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apple = usesAppleSignIn;
    final loading = ref.watch(authControllerProvider).isLoading;

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${next.error}')),
        );
      }
    });

    final label = apple ? 'Continue with Apple' : 'Continue with Google';
    final icon = apple ? Icons.apple : Icons.g_mobiledata;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: loading
            ? null
            : () async {
                final ok = await ref
                    .read(authControllerProvider.notifier)
                    .signIn();
                if (ok) onSignedIn?.call();
              },
        style: FilledButton.styleFrom(
          backgroundColor: apple ? Colors.white : null,
          foregroundColor: apple ? Colors.black : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
