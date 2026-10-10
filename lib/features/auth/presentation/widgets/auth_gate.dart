import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'sign_in_view.dart';

/// Shows [child] to signed-in users and a sign-in prompt to everyone else.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.child,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isSignedInProvider)
        ? child
        : SignInView(title: title, message: message, icon: icon);
  }
}
