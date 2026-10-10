import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigito/features/info/presentation/content/legal_content.dart';
import 'package:navigito/features/info/presentation/pages/feedback_page.dart';
import 'package:navigito/features/info/presentation/pages/legal_page.dart';

void main() {
  testWidgets('privacy policy lists its sections and a way to reach us', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LegalPage(doc: privacyPolicy)));
    expect(find.text('Privacy Policy'), findsOneWidget);
    // The list builds lazily, so scroll each heading into view.
    for (final heading in ['What we collect', 'Location', 'Services we use']) {
      await tester.scrollUntilVisible(find.text(heading), 300);
      expect(find.text(heading), findsOneWidget);
    }
    // No email set yet, so it points to the in-app form.
    final contact = find.textContaining('Profile → Send feedback');
    await tester.scrollUntilVisible(contact, 300);
    expect(contact, findsOneWidget);
  });

  testWidgets('feedback can only be sent once it says something', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeedbackPage())),
    );
    FilledButton send() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Send'), matching: find.byType(FilledButton)),
    );
    expect(send().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    expect(send().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Please add offline maps');
    await tester.pump();
    expect(send().onPressed, isNotNull);
  });
}
