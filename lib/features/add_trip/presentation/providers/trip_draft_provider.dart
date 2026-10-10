import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../trip_detail/domain/entities/trip_stop.dart';
import '../../domain/entities/new_trip.dart';

/// A place added to the trip being created.
class DraftStop {
  const DraftStop({
    required this.id,
    required this.name,
    required this.position,
    this.subtitle = '',
    this.type = StopType.attraction,
    this.day = 1,
    this.time,
  });

  /// Place id, so the same place can't be added twice.
  final String id;
  final String name;
  final String subtitle;
  final LatLng position;
  final StopType type;
  final int day;

  /// Set by the user; null means it follows on from the stop before.
  final TimeOfDay? time;

  DraftStop copyWith({StopType? type, int? day, TimeOfDay? Function()? time}) =>
      DraftStop(
        id: id,
        name: name,
        subtitle: subtitle,
        position: position,
        type: type ?? this.type,
        day: day ?? this.day,
        time: time != null ? time() : this.time,
      );
}

/// Guesses a stop's kind from its Google place types; edited in the timeline.
StopType stopTypeFor(List<String> types) {
  const food = {
    'restaurant',
    'cafe',
    'coffee_shop',
    'bakery',
    'bar',
    'food',
    'meal_takeaway',
    'meal_delivery',
    'food_court',
    'ice_cream_shop',
    'tea_house',
  };
  const stay = {
    'lodging',
    'hotel',
    'resort_hotel',
    'motel',
    'hostel',
    'guest_house',
    'bed_and_breakfast',
    'campground',
    'cottage',
    'farmstay',
    'inn',
  };
  if (types.any(food.contains) || types.any((t) => t.endsWith('_restaurant'))) {
    return StopType.food;
  }
  if (types.any(stay.contains)) return StopType.stay;
  return StopType.attraction;
}

class TripDraft {
  const TripDraft({
    this.stops = const [],
    this.days = 1,
    this.planned = false,
    this.title = '',
    this.description = '',
    this.categories = const {},
    this.isPublic = true,
  });

  /// In trip order, grouped by day (days never decrease along the list).
  final List<DraftStop> stops;
  final int days;

  /// Whether stops have been spread over days yet (first visit to the
  /// timeline); until then every stop is on day 1.
  final bool planned;

  final String title;
  final String description;
  final Set<String> categories;
  final bool isPublic;

  static const maxDays = 14;

  /// "Kochi to Munnar" from the first and last stops.
  String get suggestedTitle => switch (stops) {
    [] => '',
    [final only] => only.name,
    [final first, ..., final last] => '${first.name} to ${last.name}',
  };

  /// Each stop's time: its own if set, otherwise two hours after the stop
  /// before it that day, starting the day at 09:00.
  List<TimeOfDay> get schedule {
    final times = <TimeOfDay>[];
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final firstOfDay = i == 0 || stops[i - 1].day != s.day;
      final auto = firstOfDay
          ? const TimeOfDay(hour: 9, minute: 0)
          : _plusHours(times[i - 1], 2);
      times.add(s.time ?? auto);
    }
    return times;
  }

  static TimeOfDay _plusHours(TimeOfDay t, int hours) {
    final minutes = (t.hour + hours) * 60 + t.minute;
    // Stays on the same day; late stops bunch up at 23:00 rather than wrap.
    return minutes >= 23 * 60
        ? const TimeOfDay(hour: 23, minute: 0)
        : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// The trip to create, named [title]. Every stop gets its scheduled time,
  /// set or automatic, so the trip reads the same once published.
  NewTrip toNewTrip(String title) {
    final times = schedule;
    String hhmm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    return NewTrip(
      title: title.trim(),
      description: description.trim(),
      days: days,
      tags: categories.toList(),
      isPublic: isPublic,
      stops: [
        for (final (i, s) in stops.indexed)
          NewStop(
            day: s.day,
            time: hhmm(times[i]),
            title: s.name,
            subtitle: s.subtitle,
            type: s.type,
            latitude: s.position.latitude,
            longitude: s.position.longitude,
            // Dropped pins and pasted coordinates have no Google place.
            placeId: s.id.startsWith('geo:') ? null : s.id,
          ),
      ],
    );
  }

  TripDraft copyWith({
    List<DraftStop>? stops,
    int? days,
    bool? planned,
    String? title,
    String? description,
    Set<String>? categories,
    bool? isPublic,
  }) => TripDraft(
    stops: stops ?? this.stops,
    days: days ?? this.days,
    planned: planned ?? this.planned,
    title: title ?? this.title,
    description: description ?? this.description,
    categories: categories ?? this.categories,
    isPublic: isPublic ?? this.isPublic,
  );
}

/// The trip being created. Kept in memory while the flow is closed, so
/// leaving and coming back doesn't lose the stops.
class TripDraftNotifier extends Notifier<TripDraft> {
  @override
  TripDraft build() => const TripDraft();

  /// Adds [stop] at the end of the last day. False if it's already there.
  bool addStop(DraftStop stop) {
    if (state.stops.any((s) => s.id == stop.id)) return false;
    state = state.copyWith(
      stops: [
        ...state.stops,
        stop.copyWith(day: state.planned ? state.days : 1),
      ],
    );
    return true;
  }

  /// Removes the stop with [id]; returns it and its index, for undo.
  (int, DraftStop)? removeStop(String id) {
    final index = state.stops.indexWhere((s) => s.id == id);
    if (index < 0) return null;
    final removed = state.stops[index];
    state = state.copyWith(stops: [...state.stops]..removeAt(index));
    return (index, removed);
  }

  void insertStop(int index, DraftStop stop) {
    final stops = [...state.stops];
    stops.insert(index.clamp(0, stops.length), stop);
    state = state.copyWith(stops: _sortedByDay(stops));
  }

  void updateStop(DraftStop stop) {
    state = state.copyWith(
      stops: [for (final s in state.stops) s.id == stop.id ? stop : s],
    );
  }

  /// Reorders on the map screen. Each position keeps its day, so every day
  /// keeps as many stops as it had and stops flow into them in the new order.
  void reorder(int from, int to) {
    final slots = [for (final s in state.stops) s.day];
    final stops = [...state.stops];
    stops.insert(to, stops.removeAt(from));
    state = state.copyWith(
      stops: [
        for (var i = 0; i < stops.length; i++) stops[i].copyWith(day: slots[i]),
      ],
    );
  }

  /// Sets the timeline: stops in order, each already carrying its day.
  void setTimeline(List<DraftStop> stops) {
    state = state.copyWith(stops: _sortedByDay(stops));
  }

  /// Changes the trip length and spreads the stops evenly over it.
  void setDays(int days) {
    if (days < 1 || days > TripDraft.maxDays) return;
    state = state.copyWith(days: days, stops: _spread(state.stops, days));
  }

  /// On the first visit to the timeline, picks a trip length (about four
  /// stops a day) and spreads the stops over it.
  void planIfNeeded() {
    if (state.planned) return;
    final days = (state.stops.length / 4).ceil().clamp(1, TripDraft.maxDays);
    state = state.copyWith(
      days: days,
      planned: true,
      stops: _spread(state.stops, days),
    );
  }

  void setDetails({
    String? title,
    String? description,
    Set<String>? categories,
    bool? isPublic,
  }) {
    state = state.copyWith(
      title: title,
      description: description,
      categories: categories,
      isPublic: isPublic,
    );
  }

  void reset() => state = const TripDraft();

  static List<DraftStop> _spread(List<DraftStop> stops, int days) => [
    for (var i = 0; i < stops.length; i++)
      // Re-spreading drops hand-set times; they belonged to the old days.
      stops[i].copyWith(day: i * days ~/ stops.length + 1, time: () => null),
  ];

  static List<DraftStop> _sortedByDay(List<DraftStop> stops) {
    final indexed = stops.indexed.toList()
      ..sort((a, b) {
        final byDay = a.$2.day.compareTo(b.$2.day);
        return byDay != 0 ? byDay : a.$1.compareTo(b.$1);
      });
    return [for (final (_, s) in indexed) s];
  }
}

final tripDraftProvider = NotifierProvider<TripDraftNotifier, TripDraft>(
  TripDraftNotifier.new,
);
