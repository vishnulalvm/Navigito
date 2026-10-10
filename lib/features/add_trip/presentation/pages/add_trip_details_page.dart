import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../domain/repositories/add_trip_repository.dart';
import '../../domain/usecases/create_trip.dart';
import '../providers/photo_uploads_provider.dart';
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
  final _formKey = GlobalKey<FormState>();

  // Starts from what was typed before, or a title made from the stops.
  late final TripDraft _initial = ref.read(tripDraftProvider);
  late final _title = TextEditingController(
    text: _initial.title.isEmpty ? _initial.suggestedTitle : _initial.title,
  );
  late final _description = TextEditingController(text: _initial.description);

  TripDraftNotifier get _draft => ref.read(tripDraftProvider.notifier);

  /// The create request is in flight; the button waits and can't resend.
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Publishes the trip with all its stops in one request. On failure the
  /// draft stays, so nothing is lost and Create can be tapped again.
  Future<void> _create() async {
    if (_creating ||
        ref.read(photoUploadsProvider.notifier).busy ||
        !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _creating = true);

    final newTrip = ref.read(tripDraftProvider).toNewTrip(_title.text);
    final result = await CreateTrip(sl<AddTripRepository>())(newTrip);
    if (!mounted) return;
    setState(() => _creating = false);

    result.fold((f) => showErrorSnack(context, f.message), (_) {
      _draft.reset();
      ref
        ..invalidate(myTripsProvider(MyTripsTab.mine))
        ..invalidate(tripsProvider);
      ref.read(myTripsTabProvider.notifier).state = MyTripsTab.mine;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip published')));
      context.go(AppRouter.myTrips);
    });
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
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          // Photos picked a moment ago must land before the trip is sent.
          final uploading = ref.watch(
            photoUploadsProvider.select(
              (p) => p.values.any((l) => l.isNotEmpty),
            ),
          );
          return AddTripBottomAction(
            label: _creating
                ? 'Publishing…'
                : uploading
                ? 'Uploading photos…'
                : 'Create trip',
            icon: Icons.check,
            loading: _creating || uploading,
            onPressed: _create,
          );
        },
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
