import 'package:flutter/material.dart';

import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../../trip_detail/presentation/widgets/stop_style.dart';
import 'draft_stop.dart';

Future<DraftStop?> showAddStopSheet(BuildContext context, {required int days}) {
  return showModalBottomSheet<DraftStop>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddStopSheet(days: days),
  );
}

class _AddStopSheet extends StatefulWidget {
  const _AddStopSheet({required this.days});
  final int days;

  @override
  State<_AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<_AddStopSheet> {
  final _name = TextEditingController();
  StopType _type = StopType.attraction;
  int _day = 1;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add stop',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Place name',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<StopType>(
            showSelectedIcon: false,
            segments: [
              for (final t in [
                StopType.attraction,
                StopType.food,
                StopType.stay,
              ])
                ButtonSegment(
                  value: t,
                  label: Text(t.label),
                  icon: Icon(t.icon, size: 16),
                ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _day,
                  decoration: InputDecoration(
                    labelText: 'Day',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    for (var d = 1; d <= widget.days; d++)
                      DropdownMenuItem(value: d, child: Text('Day $d')),
                  ],
                  onChanged: (v) => setState(() => _day = v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (t != null) setState(() => _time = t);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) {
                  setState(() => _error = 'Enter a place name');
                  return;
                }
                Navigator.pop(
                  context,
                  DraftStop(name: name, type: _type, day: _day, time: _time),
                );
              },
              child: const Text('Add stop'),
            ),
          ),
        ],
      ),
    );
  }
}
