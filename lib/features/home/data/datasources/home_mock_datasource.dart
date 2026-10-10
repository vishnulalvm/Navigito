import '../../domain/entities/map_place.dart';
import '../../domain/entities/trip.dart';

/// Sample Kerala data. Replace with a remote datasource when the backend exists.
class HomeMockDatasource {
  static const _munnar =
      'https://images.unsplash.com/photo-1593693397690-362cb9666fc2?w=800';
  static const _falls =
      'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800';
  static const _hills =
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400';
  static const _food =
      'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400';
  static const _tea =
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800';
  static const _avatarA =
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100';
  static const _avatarB =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100';

  Future<List<Trip>> trips() async => const [
    Trip(
      id: 't1',
      title: 'Kochi to Munnar',
      coverUrl: _munnar,
      days: 2,
      stops: 8,
      authorName: 'Arjun',
      authorAvatarUrl: _avatarA,
      likes: 1200,
      places: [
        'kochi',
        'angamaly',
        'athirappilly',
        'vazhachal',
        'adimali',
        'cheeyappara',
        'munnar',
        'kerala',
      ],
      isFavorite: true,
    ),
    Trip(
      id: 't2',
      title: 'Athirappilly Day Trip',
      coverUrl: _falls,
      days: 1,
      stops: 6,
      authorName: 'Sneha',
      authorAvatarUrl: _avatarB,
      likes: 856,
      places: [
        'kochi',
        'angamaly',
        'athirappilly',
        'vazhachal',
        'chalakudy',
        'kerala',
      ],
      isFavorite: true,
    ),
    Trip(
      id: 't3',
      title: 'Wayanad Weekend',
      coverUrl: _tea,
      days: 3,
      stops: 10,
      authorName: 'Rohit',
      authorAvatarUrl: _avatarA,
      likes: 640,
      places: [
        'kozhikode',
        'calicut',
        'lakkidi',
        'vythiri',
        'wayanad',
        'kerala',
      ],
      distanceKm: 420,
    ),
    Trip(
      id: 't4',
      title: 'Kozhikode Food Trail',
      coverUrl: _food,
      days: 1,
      stops: 8,
      authorName: 'Neha',
      authorAvatarUrl: _avatarB,
      likes: 920,
      places: ['kozhikode', 'calicut', 'mananchira', 'kerala'],
      distanceKm: 160,
    ),
  ];

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
