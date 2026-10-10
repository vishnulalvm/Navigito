import 'package:flutter/material.dart';

/// Shows [message] as a snackbar, replacing any shown one; null shows
/// nothing, so a call can pass an action's result straight in.
void showErrorSnack(BuildContext context, String? message) {
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
