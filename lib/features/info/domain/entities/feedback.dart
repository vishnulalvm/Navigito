enum FeedbackKind {
  idea('Idea'),
  bug('Problem'),
  other('Other');

  const FeedbackKind(this.label);
  final String label;
}

class FeedbackMessage {
  const FeedbackMessage({
    required this.kind,
    required this.message,
    this.appVersion,
    this.platform,
  });

  final FeedbackKind kind;
  final String message;
  final String? appVersion;
  final String? platform;
}
