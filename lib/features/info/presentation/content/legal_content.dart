import '../../../../core/constants/app_info.dart';

/// One heading with its paragraphs and bullet points.
class LegalSection {
  const LegalSection(
    this.heading, {
    this.paragraphs = const [],
    this.bullets = const [],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

class LegalDoc {
  const LegalDoc({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

/// How to reach us: the contact email once set, else the in-app form.
String get _contact => AppInfo.hasContact
    ? 'Email us at ${AppInfo.contactEmail}'
    : 'Use Send feedback in the app (Profile → Send feedback)';

// Written to match what the app does today. Have it reviewed before release,
// and update AppInfo.legalUpdated whenever it changes.

LegalDoc get privacyPolicy => LegalDoc(
  title: 'Privacy Policy',
  intro:
      '${AppInfo.name} helps you discover and share road trips. This policy '
      'explains what we collect, why, and the choices you have.',
  sections: [
    const LegalSection(
      'What we collect',
      bullets: [
        'Account details: your name, email address and profile photo, from '
            'the Google or Apple account you sign in with.',
        'Trips you create: titles, descriptions, stops (names, places, '
            'coordinates and times), categories and the photos you upload.',
        'Your activity: the trips you like and save, and the travellers you '
            'follow.',
        'Feedback you send us, with the app version and platform.',
      ],
    ),
    const LegalSection(
      'Location',
      paragraphs: [
        'With your permission, the app uses your device\'s location to show '
            'trips and places near you. It is sent only to find nearby trips '
            'and to rank place search results, and is not stored in your '
            'account. You can turn location access off in your device '
            'settings at any time.',
      ],
    ),
    const LegalSection(
      'What others can see',
      paragraphs: [
        'Public trips, with their stops and photos, your name and profile '
            'photo, can be seen by anyone using the app. Private trips are '
            'visible only to you. Your likes, saves and email address are '
            'never shown to others.',
      ],
    ),
    const LegalSection(
      'Services we use',
      paragraphs: [
        'We rely on these providers to run the app. They process data only '
            'to provide their service:',
      ],
      bullets: [
        'Supabase: account sign-in, database and photo storage.',
        'Google: Google Sign-In, and Google Maps, Places and Routes for the '
            'map, place search, place photos and routes. What you type in '
            'search is sent to Google to find places.',
        'Apple: Sign in with Apple, on iPhone.',
      ],
    ),
    const LegalSection(
      'What we don\'t do',
      bullets: [
        'We don\'t sell your data.',
        'We don\'t show ads or track you across other apps and websites.',
      ],
    ),
    const LegalSection(
      'On your device',
      paragraphs: [
        'Your recent searches and last map position are stored only on your '
            'device, to make the app faster. Clearing the app\'s data removes '
            'them.',
      ],
    ),
    const LegalSection(
      'Keeping and deleting your data',
      paragraphs: [
        'We keep your data while you have an account. You can delete your '
            'account at any time from Profile → Delete account: your trips, '
            'photos, likes, saves, follows and feedback are deleted for good.',
      ],
    ),
    const LegalSection(
      'Children',
      paragraphs: [
        '${AppInfo.name} is not meant for children under 13, and we don\'t '
            'knowingly collect their data.',
      ],
    ),
    const LegalSection(
      'Changes',
      paragraphs: [
        'If this policy changes, we will update the date below and, for '
            'important changes, let you know in the app.',
      ],
    ),
    LegalSection(
      'Contact',
      paragraphs: ['Questions about your privacy or your data? $_contact.'],
    ),
  ],
);

LegalDoc get termsAndConditions => LegalDoc(
  title: 'Terms & Conditions',
  intro:
      'By using ${AppInfo.name}, you agree to these terms. Please read them '
      'with our Privacy Policy.',
  sections: [
    const LegalSection(
      'Your account',
      paragraphs: [
        'You sign in with Google or Apple and are responsible for what '
            'happens in your account. You can delete it at any time from your '
            'profile.',
      ],
    ),
    const LegalSection(
      'Your content',
      paragraphs: [
        'You own the trips and photos you share. By making a trip public, '
            'you let us show it, with its photos, to other users of the app. '
            'Only share photos you took or have the right to share.',
      ],
    ),
    const LegalSection(
      'Acceptable use',
      paragraphs: ['Don\'t use the app to:'],
      bullets: [
        'post anything illegal, hateful, harassing or sexually explicit;',
        'share other people\'s personal information without their consent;',
        'spam, mislead others, or interfere with the app or its users.',
      ],
    ),
    const LegalSection(
      'Travel at your own risk',
      paragraphs: [
        'Trips are shared by other travellers. Routes, times, places and '
            'conditions can be wrong or out of date. Check before you go, '
            'follow local laws and road rules, and use your own judgement. '
            'Never use the app in a way that distracts you while driving.',
      ],
    ),
    const LegalSection(
      'Maps and places',
      paragraphs: [
        'Maps, place information and some photos are provided by Google. '
            'Your use of them is also subject to the Google Maps Terms of '
            'Service (maps.google.com/help/terms_maps) and Google\'s Privacy '
            'Policy (policies.google.com/privacy). Photos from Google remain '
            'the property of their authors.',
      ],
    ),
    const LegalSection(
      'Removing content and accounts',
      paragraphs: [
        'We may remove content or suspend accounts that break these terms.',
      ],
    ),
    const LegalSection(
      'The service',
      paragraphs: [
        'The app is provided "as is". We work to keep it available and '
            'accurate but can\'t promise it will always be error-free or '
            'uninterrupted. To the extent the law allows, we are not liable '
            'for losses arising from your use of the app or from trips shared '
            'in it.',
      ],
    ),
    const LegalSection(
      'Changes',
      paragraphs: [
        'We may update these terms. If we make important changes, we will '
            'let you know in the app. Continuing to use the app means you '
            'accept the updated terms.',
      ],
    ),
    LegalSection('Contact', paragraphs: ['Questions? $_contact.']),
  ],
);
