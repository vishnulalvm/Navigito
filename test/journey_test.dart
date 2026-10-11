import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigito/core/di/injection.dart';
import 'package:navigito/features/journey/data/datasources/journey_local_datasource.dart';
import 'package:navigito/features/journey/data/repositories/journey_repository_impl.dart';
import 'package:navigito/features/journey/domain/entities/journey_progress.dart';
import 'package:navigito/features/journey/domain/repositories/journey_repository.dart';
import 'package:navigito/features/journey/presentation/pages/journey_page.dart';
import 'package:navigito/features/journey/presentation/providers/journey_providers.dart';
import 'package:navigito/features/trip_detail/domain/entities/trip_detail.dart';
import 'package:navigito/features/trip_detail/domain/entities/trip_stop.dart';
import 'package:navigito/features/trip_detail/presentation/providers/trip_detail_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

TripStop _stop(String id, String title, String time, StopType type) => TripStop(
  id: id,
  day: 1,
  time: time,
  title: title,
  type: type,
  latitude: 10,
  longitude: 76,
  travelMinutes: id == 'a' ? null : 90,
  distanceKm: id == 'a' ? null : 55,
);

final _trip = TripDetail(
  id: 't1',
  title: 'Kochi to Munnar',
  coverUrl: '',
  description: '',
  tags: const [],
  authorId: 'u1',
  authorName: 'Arjun',
  authorAvatarUrl: '',
  days: 1,
  distanceKm: 286,
  likes: 0,
  comments: 0,
  startDate: DateTime(2026, 10, 12),
  stops: [
    _stop('a', 'Start from Kochi', '06:00', StopType.start),
    _stop('b', 'Breakfast', '07:30', StopType.food),
    _stop('c', 'Athirappilly Waterfalls', '09:15', StopType.attraction),
  ],
);

class _FakeTripDetail extends TripDetailNotifier {
  @override
  Future<TripDetail> build(String arg) async => _trip;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await sl.reset();
    sl.registerSingleton<JourneyRepository>(
      JourneyRepositoryImpl(JourneyLocalDatasource(prefs)),
    );
  });

  test('progress survives a round trip through storage', () async {
    final local = JourneyLocalDatasource(prefs);
    final p = JourneyProgress(
      tripId: 't1',
      startedAt: DateTime(2026, 10, 12, 6),
    ).reach('a', DateTime(2026, 10, 12, 6, 2));
    await local.save(p);
    expect(local.read('t1'), p);
    await local.clear('t1');
    expect(local.read('t1'), isNull);
  });

  test('the next stop is the first one not reached', () {
    final p = JourneyProgress(
      tripId: 't1',
      startedAt: DateTime(2026),
    ).reach('a', DateTime(2026));
    expect(nextStop(_trip.stops, p)?.id, 'b');
    expect(nextStop(_trip.stops, null)?.id, 'a');
  });

  testWidgets('only the upcoming stop offers actions; reaching moves on', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripDetailProvider.overrideWith(_FakeTripDetail.new)],
        child: const MaterialApp(home: JourneyPage(tripId: 't1')),
      ),
    );
    // The live dot pulses forever, so pump frames rather than settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Trip in Progress'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Mark reached'), findsOneWidget);
    expect(find.text('Reached'), findsNothing);
    expect(find.text('Next Stop'), findsOneWidget); // The start has no drive.

    await tester.tap(find.text('Mark reached'));
    await tester.pump();

    // Kochi is reached; Breakfast is now the one with actions.
    expect(find.text('Reached'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(prefs.getString('journey:t1'), isNotNull);
  });
}
