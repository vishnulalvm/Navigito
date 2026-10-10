import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_info.dart';
import '../content/legal_content.dart';

/// Privacy Policy or Terms, readable offline.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Only developers see this; release builds never do.
            if (kDebugMode && !AppInfo.hasContact)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Set AppInfo.contactEmail (lib/core/constants/app_info.dart) '
                  'before release.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            Text(doc.intro, style: body),
            for (final section in doc.sections) ...[
              const SizedBox(height: 22),
              Text(
                section.heading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final p in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(p, style: body),
                ),
              for (final b in section.bullets)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: body),
                      Expanded(child: Text(b, style: body)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 28),
            Text(
              'Last updated ${AppInfo.legalUpdated}',
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
