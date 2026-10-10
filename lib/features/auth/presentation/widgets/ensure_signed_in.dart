import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import 'social_sign_in_button.dart';

/// Gate for actions (like, save, follow...). Returns true if the user is signed
/// in, prompting them with a bottom sheet first when they are not.
Future<bool> ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  String reason = 'Sign in to continue',
}) async {
  if (ref.read(isSignedInProvider)) return true;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reason,
            textAlign: TextAlign.center,
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a free account to save, like and share trips.',
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
              color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SocialSignInButton(
            onSignedIn: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );

  // Read the repository directly: the auth stream may lag a frame behind.
  return sl<AuthRepository>().currentUser != null;
}
