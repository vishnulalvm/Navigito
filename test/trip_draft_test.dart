import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navigito/features/add_trip/presentation/providers/trip_draft_provider.dart';
import 'package:navigito/features/auth/domain/entities/auth_user.dart';
import 'package:navigito/features/auth/presentation/providers/auth_providers.dart';
import 'package:navigito/features/trip_detail/domain/entities/trip_stop.dart';

DraftStop _stop(String id) =>
    DraftStop(id: id, name: id, position: const LatLng(10, 76));

void main() {
  late ProviderContainer container;
  TripDraftNotifier draft() => container.read(tripDraftProvider.notifier);
  TripDraft state() => container.read(tripDraftProvider);
  List<String> ids() => [for (final s in state().stops) s.id];
  List<int> days() => [for (final s in state().stops) s.day];

  setUp(() async {
    container = _container();
    // The draft resets when the user changes; settle on the user first.
    container.listen(tripDraftProvider, (_, _) {});
    await container.read(authUserProvider.future);
    for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) {
      draft().addStop(_stop(id));
    }
  });
  tearDown(() => container.dispose());

  test('switching accounts starts a fresh draft', () async {
    final user = StreamController<AuthUser?>();
    final c = ProviderContainer(
      overrides: [authUserProvider.overrideWith((ref) => user.stream)],
    );
    addTearDown(() {
      c.dispose();
      user.close();
    });
    c.listen(tripDraftProvider, (_, _) {});
    user.add(const AuthUser(id: 'u1', name: 'A'));
    await Future<void>.delayed(Duration.zero);
    c.read(tripDraftProvider.notifier).addStop(_stop('a'));
    expect(c.read(tripDraftProvider).stops, hasLength(1));

    user.add(const AuthUser(id: 'u2', name: 'B'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(tripDraftProvider).stops, isEmpty);
  });

  test('rejects a place already in the trip', () {
    expect(draft().addStop(_stop('a')), isFalse);
    expect(state().stops, hasLength(6));
  });

  test('first plan picks about four stops a day and spreads them', () {
    draft().planIfNeeded();
    expect(state().days, 2);
    expect(days(), [1, 1, 1, 2, 2, 2]);
  });

  test('changing days re-spreads evenly and drops set times', () {
    draft().planIfNeeded();
    draft().updateStop(
      state().stops.first.copyWith(
        time: () => const TimeOfDay(hour: 7, minute: 0),
      ),
    );
    draft().setDays(3);
    expect(days(), [1, 1, 2, 2, 3, 3]);
    expect(state().stops.first.time, isNull);
  });

  test('reordering keeps how many stops each day has', () {
    draft().planIfNeeded();
    draft().reorder(5, 0); // f to the front
    expect(ids(), ['f', 'a', 'b', 'c', 'd', 'e']);
    expect(days(), [1, 1, 1, 2, 2, 2]);
  });

  test('stops added after planning join the last day', () {
    draft().planIfNeeded();
    draft().addStop(_stop('g'));
    expect(state().stops.last.day, 2);
  });

  test('times run two hours apart from 09:00 each day, set times anchor', () {
    draft().planIfNeeded();
    draft().updateStop(
      state().stops[1].copyWith(
        time: () => const TimeOfDay(hour: 14, minute: 30),
      ),
    );
    final times = [for (final t in state().schedule) (t.hour, t.minute)];
    expect(times, [(9, 0), (14, 30), (16, 30), (9, 0), (11, 0), (13, 0)]);
  });

  test('undo puts a removed stop back where it was', () {
    final (index, stop) = draft().removeStop('c')!;
    draft().insertStop(index, stop);
    expect(ids(), ['a', 'b', 'c', 'd', 'e', 'f']);
  });

  test('title suggestion uses the first and last stop', () {
    expect(state().suggestedTitle, 'a to f');
  });

  test('stop type from Google place types', () {
    expect(stopTypeFor(['indian_restaurant', 'food']), StopType.food);
    expect(stopTypeFor(['lodging']), StopType.stay);
    expect(stopTypeFor(['tourist_attraction']), StopType.attraction);
    expect(stopTypeFor(const []), StopType.attraction);
  });
}

/// Signed in as one user, without the real auth backend.
ProviderContainer _container() => ProviderContainer(
  overrides: [
    authUserProvider.overrideWith(
      (ref) => Stream.value(const AuthUser(id: 'u1', name: 'Arjun')),
    ),
  ],
);
