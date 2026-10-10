import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../home/domain/entities/trip.dart';
import '../../../main_shell/presentation/widgets/floating_nav_bar.dart';
import '../../../my_trips/domain/repositories/my_trips_repository.dart';
import '../../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';
import '../widgets/add_stop_sheet.dart';
import '../widgets/draft_stop.dart';

class AddTripPage extends ConsumerStatefulWidget {
  const AddTripPage({super.key});

  @override
  ConsumerState<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends ConsumerState<AddTripPage> {
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
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _categoriesSelected = <String>{};
  final _stops = <DraftStop>[];
  int _days = 1;
  bool _isPublic = true;
  bool _stopsError = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addStop() async {
    final stop = await showAddStopSheet(context, days: _days);
    if (stop == null) return;
    setState(() {
      _stops.add(stop);
      _stops.sort((a, b) {
        final byDay = a.day.compareTo(b.day);
        if (byDay != 0) return byDay;
        return (a.time.hour * 60 + a.time.minute).compareTo(
          b.time.hour * 60 + b.time.minute,
        );
      });
      _stopsError = false;
    });
  }

  void _setDays(int days) {
    if (days < 1 || days > 14) return;
    setState(() {
      _days = days;
      // Keep stops inside the new range.
      _stops.removeWhere((s) => s.day > days);
    });
  }

  void _create() {
    final valid = _formKey.currentState!.validate();
    setState(() => _stopsError = _stops.isEmpty);
    if (!valid || _stops.isEmpty) return;

    final trip = Trip(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim(),
      coverUrl: _placeholderCover,
      days: _days,
      stops: _stops.length,
      authorName: 'You',
      authorAvatarUrl: _selfAvatar,
      likes: 0,
    );
    ref.read(myTripsProvider(MyTripsTab.mine).notifier).add(trip);
    ref.read(myTripsTabProvider.notifier).state = MyTripsTab.mine;

    _title.clear();
    _description.clear();
    setState(() {
      _categoriesSelected.clear();
      _stops.clear();
      _days = 1;
      _isPublic = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trip created')));
    context.go(AppRouter.myTrips);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              FloatingNavBar.reservedSpace(context) + 8,
            ),
            children: [
              Text(
                'Add Trip',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.words,
                decoration: deco('Trip title', hint: 'e.g. Kochi to Munnar'),
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
                  'Description',
                  hint: 'What makes this trip special?',
                ),
              ),
              heading('Duration'),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _days > 1 ? () => _setDays(_days - 1) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Expanded(
                        child: Text(
                          '$_days ${_days == 1 ? 'Day' : 'Days'}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: _days < 14
                            ? () => _setDays(_days + 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
              heading('Categories'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _categories)
                    FilterChip(
                      label: Text(c),
                      selected: _categoriesSelected.contains(c),
                      onSelected: (on) => setState(
                        () => on
                            ? _categoriesSelected.add(c)
                            : _categoriesSelected.remove(c),
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
                selected: {_isPublic},
                onSelectionChanged: (s) => setState(() => _isPublic = s.first),
              ),
              heading('Stops'),
              for (var i = 0; i < _stops.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _stops[i].type.color,
                        child: Icon(
                          _stops[i].type.icon,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(_stops[i].name),
                      subtitle: Text(
                        'Day ${_stops[i].day} · ${_stops[i].timeLabel}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _stops.removeAt(i)),
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _addStop,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add stop'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_stopsError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Add at least one stop',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _create,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Create Trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
