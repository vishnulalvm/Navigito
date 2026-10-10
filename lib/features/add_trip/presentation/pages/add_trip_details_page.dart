import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../home/domain/entities/trip.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../providers/trip_draft_provider.dart';
import '../widgets/add_trip_bottom_action.dart';
import '../widgets/step_progress.dart';
import '../widgets/stop_badge.dart';

/// Step 3: name and describe the trip, then create it.
class AddTripDetailsPage extends ConsumerStatefulWidget {
  const AddTripDetailsPage({super.key});

  @override
  ConsumerState<AddTripDetailsPage> createState() => _AddTripDetailsPageState();
}

class _AddTripDetailsPageState extends ConsumerState<AddTripDetailsPage> {
  static const _categories = [
    'Nature',
    'Food',
    'Hidden Spots',
    'Road Trip',
    'Adventure',
    'Beach',
  ];
  static const _placeholderCover =
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400';
  static const _selfAvatar =
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100';

  final _formKey = GlobalKey<FormState>();

  // Starts from what was typed before, or a title made from the stops.
  late final TripDraft _initial = ref.read(tripDraftProvider);
  late final _title = TextEditingController(
    text: _initial.title.isEmpty ? _initial.suggestedTitle : _initial.title,
  );
  late final _description = TextEditingController(text: _initial.description);

  TripDraftNotifier get _draft => ref.read(tripDraftProvider.notifier);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _create() {
    if (!_formKey.currentState!.validate()) return;
    final draft = ref.read(tripDraftProvider);

    final trip = Trip(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim(),
      coverUrl: _placeholderCover,
      days: draft.days,
      stops: draft.stops.length,
      authorName: 'You',
      authorAvatarUrl: _selfAvatar,
      likes: 0,
      places: [for (final s in draft.stops) s.name.toLowerCase()],
    );
    ref.read(myTripsProvider(MyTripsTab.mine).notifier).add(trip);
    ref.read(myTripsTabProvider.notifier).state = MyTripsTab.mine;
    _draft.reset();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trip created')));
    context.go(AppRouter.myTrips);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = ref.watch(tripDraftProvider);

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip details'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(36),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: StepProgress(step: 3, label: 'Details'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Summary(draft: draft),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: deco('Trip title', hint: 'e.g. Kochi to Munnar'),
              onChanged: (v) => _draft.setDetails(title: v),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Enter at least 3 characters'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco(
                'Description (optional)',
                hint: 'What makes this trip special?',
              ),
              onChanged: (v) => _draft.setDetails(description: v),
            ),
            heading('Categories'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  FilterChip(
                    label: Text(c),
                    selected: draft.categories.contains(c),
                    onSelected: (on) => _draft.setDetails(
                      categories: on
                          ? {...draft.categories, c}
                          : ({...draft.categories}..remove(c)),
                    ),
                  ),
              ],
            ),
            heading('Visibility'),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Public'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Private'),
                  icon: Icon(Icons.lock_outline),
                ),
              ],
              selected: {draft.isPublic},
              onSelectionChanged: (s) => _draft.setDetails(isPublic: s.first),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AddTripBottomAction(
        label: 'Create trip',
        icon: Icons.check,
        onPressed: _create,
      ),
    );
  }
}

/// What the trip covers, as a reminder while naming it.
class _Summary extends StatelessWidget {
  const _Summary({required this.draft});

  final TripDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stops = draft.stops;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stops.length} ${stops.length == 1 ? 'stop' : 'stops'} · '
              '${draft.days} ${draft.days == 1 ? 'day' : 'days'}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stops.length,
                separatorBuilder: (_, _) => Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                itemBuilder: (_, i) => Row(
                  children: [
                    StopBadge(type: stops[i].type, number: i + 1, size: 22),
                    const SizedBox(width: 6),
                    Text(stops[i].name, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
