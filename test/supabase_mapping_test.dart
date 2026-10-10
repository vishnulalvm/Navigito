import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navigito/features/add_trip/presentation/providers/trip_draft_provider.dart';
import 'package:navigito/features/home/data/models/trip_card_model.dart';
import 'package:navigito/features/trip_detail/data/models/trip_detail_model.dart';
import 'package:navigito/features/trip_detail/domain/entities/trip_stop.dart';

// Fixtures are real output of `feed_trips` and `trip_detail` from the
// migrations, captured from a local database.
const _card = '''
{"id":"f4770346-d0e6-4a37-b5fb-a5ee56858525","author_id":"aaaaaaaa-0000-0000-0000-000000000001","title":"Kochi to Munnar","cover_url":null,"days":2,"distance_km":0,"tags":["Nature","Road Trip"],"is_public":true,"likes_count":1,"created_at":"2026-10-10T21:44:12.065795+05:30","author_name":"Arjun","author_avatar_url":null,"stops_count":3,"places":["fort kochi kochi, kerala","kashi cafe","tea museum munnar"],"is_liked":true,"is_saved":true}
''';

const _detail = '''
{"id" : "f4770346-d0e6-4a37-b5fb-a5ee56858525", "title" : "Kochi to Munnar", "description" : "", "cover_url" : null, "tags" : ["Nature","Road Trip"], "days" : 2, "distance_km" : 0, "likes_count" : 1, "comments_count" : 0, "is_public" : true, "start_date" : "2026-10-10", "author" : {"id" : "aaaaaaaa-0000-0000-0000-000000000001", "name" : "Arjun", "avatar_url" : null}, "is_liked" : true, "is_saved" : true, "is_following" : false, "stops" : [{"id" : "11828b66-9987-45ce-8975-c341d63705df", "day" : 1, "time" : "09:00", "title" : "Fort Kochi", "subtitle" : "Kochi, Kerala", "type" : "attraction", "latitude" : 9.96, "longitude" : 76.24, "photo_url" : null, "place_id" : "g1", "travel_minutes" : null, "distance_km" : null}, {"id" : "23254cac-f133-4766-b451-fd6e19dbfc6c", "day" : 1, "time" : null, "title" : "Kashi Cafe", "subtitle" : null, "type" : "food", "latitude" : 9.97, "longitude" : 76.25, "photo_url" : null, "place_id" : null, "travel_minutes" : null, "distance_km" : null}, {"id" : "42150629-1d48-4bea-9a84-2db738c4ed66", "day" : 2, "time" : "10:30", "title" : "Tea Museum", "subtitle" : "Munnar", "type" : "attraction", "latitude" : 10, "longitude" : 77.06, "photo_url" : null, "place_id" : null, "travel_minutes" : null, "distance_km" : null}]}
''';

void main() {
  test('trip card row maps to a Trip', () {
    final trip = tripFromCard(jsonDecode(_card) as Map<String, dynamic>);
    expect(trip.title, 'Kochi to Munnar');
    expect(trip.stops, 3);
    expect(trip.likes, 1);
    expect(trip.authorName, 'Arjun');
    // Missing images become empty strings the widgets fall back on.
    expect(trip.coverUrl, '');
    expect(trip.authorAvatarUrl, '');
    // The card heart is the save (favourite) flag.
    expect(trip.isFavorite, isTrue);
    expect(trip.places, contains('tea museum munnar'));
    expect(tripsFromCards(null), isEmpty);
  });

  test('trip detail document maps with stops in order', () {
    final d = tripDetailFromJson(jsonDecode(_detail) as Map<String, dynamic>);
    expect(d.authorId, 'aaaaaaaa-0000-0000-0000-000000000001');
    expect((d.isLiked, d.isSaved, d.isFollowing), (true, true, false));
    expect(d.startDate, DateTime(2026, 10, 10));
    expect(
      [for (final s in d.stops) s.title],
      ['Fort Kochi', 'Kashi Cafe', 'Tea Museum'],
    );
    expect(d.stops[1].type, StopType.food);
    expect(d.stops[1].time, '');
    expect(d.stops[2].day, 2);
    // Whole-number coordinates come back as ints in JSON.
    expect(d.stops[2].latitude, 10.0);
  });

  test('a draft becomes the create_trip payload with every time filled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = container.read(tripDraftProvider.notifier)
      ..addStop(
        const DraftStop(
          id: 'ChIJgoogle',
          name: 'Fort Kochi',
          subtitle: 'Kochi',
          position: LatLng(9.96, 76.24),
        ),
      )
      ..addStop(
        const DraftStop(
          id: 'geo:9.970000,76.250000',
          name: '9.97000, 76.25000',
          position: LatLng(9.97, 76.25),
          type: StopType.food,
        ),
      );
    final first = container.read(tripDraftProvider).stops.first;
    draft
      ..updateStop(
        first.copyWith(time: () => const TimeOfDay(hour: 7, minute: 5)),
      )
      ..setDetails(description: '  Weekend  ', categories: {'Nature'});

    final trip = container.read(tripDraftProvider).toNewTrip('  Kochi trip ');
    expect(trip.title, 'Kochi trip');
    expect(trip.description, 'Weekend');
    expect(trip.tags, ['Nature']);
    expect([for (final s in trip.stops) s.time], ['07:05', '09:05']);
    expect(trip.stops.first.placeId, 'ChIJgoogle');
    // Dropped pins aren't Google places.
    expect(trip.stops.last.placeId, isNull);
    expect(trip.stops.last.type, StopType.food);
  });
}
