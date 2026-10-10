import '../../domain/entities/map_place.dart';

/// Sample Kerala places for the map's photo markers. Trips come from
/// Supabase.
class HomeMockDatasource {
  static const _falls =
      'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800';
  static const _hills =
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400';
  static const _food =
      'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400';

  Future<List<MapPlace>> places() async => const [
    MapPlace(
      id: 'p1',
      name: 'Athirappilly',
      latitude: 10.2850,
      longitude: 76.5697,
      photoUrl: _falls,
    ),
    MapPlace(
      id: 'p2',
      name: 'Kodanad',
      latitude: 10.1900,
      longitude: 76.5000,
      photoUrl: _hills,
    ),
    MapPlace(
      id: 'p3',
      name: 'Piravom Hills',
      latitude: 9.9900,
      longitude: 76.5400,
      photoUrl: _hills,
    ),
    MapPlace(
      id: 'p4',
      name: 'Kakkanad Food Street',
      latitude: 9.9700,
      longitude: 76.3500,
      photoUrl: _food,
    ),
  ];
}
