import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigito/features/home/domain/entities/trip.dart';
import 'package:navigito/features/home/presentation/widgets/trip_card.dart';

void main() {
  testWidgets('TripCard shows trip details and toggles favorite', (
    tester,
  ) async {
    var tapped = false;
    const trip = Trip(
      id: 't1',
      title: 'Kochi to Munnar',
      coverUrl: '',
      days: 2,
      stops: 8,
      authorName: 'Arjun',
      authorAvatarUrl: '',
      likes: 1200,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripCard(trip: trip, onFavorite: () => tapped = true),
          ),
        ),
      ),
    );

    expect(find.text('Kochi to Munnar'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('8 stops'), findsOneWidget);
    expect(find.text('Arjun'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    expect(tapped, isTrue);
  });
}
