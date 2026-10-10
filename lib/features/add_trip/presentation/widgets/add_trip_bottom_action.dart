import 'package:flutter/material.dart';

/// Full-width primary button pinned above the system bar.
class AddTripBottomAction extends StatelessWidget {
  const AddTripBottomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Shows a spinner and ignores taps while the action runs.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: loading ? null : onPressed,
          iconAlignment: IconAlignment.end,
          icon: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
