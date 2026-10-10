import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_info.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/snackbar.dart';
import '../../domain/entities/feedback.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../domain/usecases/send_feedback.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  // Same bounds as the database's check.
  static const _minLength = 5;
  static const _maxLength = 2000;

  final _message = TextEditingController();
  FeedbackKind _kind = FeedbackKind.idea;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _valid => _message.text.trim().length >= _minLength;

  Future<void> _send() async {
    if (!_valid || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final result = await SendFeedback(sl<FeedbackRepository>())(
      FeedbackMessage(
        kind: _kind,
        message: _message.text,
        appVersion: ref.read(appVersionProvider).valueOrNull,
        platform: defaultTargetPlatform.name,
      ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    result.fold((f) => showErrorSnack(context, f.message), (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your feedback was sent.')),
      );
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Tell us what you like, what\'s broken, or what you\'d like to '
              'see next. We read every message.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<FeedbackKind>(
              showSelectedIcon: false,
              segments: [
                for (final k in FeedbackKind.values)
                  ButtonSegment(
                    value: k,
                    label: Text(k.label),
                    icon: Icon(switch (k) {
                      FeedbackKind.idea => Icons.lightbulb_outline,
                      FeedbackKind.bug => Icons.bug_report_outlined,
                      FeedbackKind.other => Icons.chat_bubble_outline,
                    }, size: 18),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              minLines: 6,
              maxLines: 12,
              maxLength: _maxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: switch (_kind) {
                  FeedbackKind.idea => 'What would make Navigito better?',
                  FeedbackKind.bug => 'What happened, and what did you expect?',
                  FeedbackKind.other => 'Your message',
                },
                filled: true,
                fillColor: scheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _valid && !_sending ? _send : null,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending…' : 'Send'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We include your app version and phone type to help fix '
              'problems.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
