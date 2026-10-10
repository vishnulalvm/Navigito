import '../../../home/domain/entities/trip.dart';
import '../../domain/repositories/my_trips_repository.dart';

/// Sample data. Replace with a remote datasource when the backend exists.
class MyTripsMockDatasource {
  static const _u = 'https://images.unsplash.com/';
  static const _munnar = '${_u}photo-1593693397690-362cb9666fc2?w=400';
  static const _falls = '${_u}photo-1432405972618-c60b0225b8f9?w=400';
  static const _tea = '${_u}photo-1500530855697-b586d89ba3ee?w=400';
  static const _food = '${_u}photo-1589302168068-964664d93dc0?w=400';
  static const _a1 = '${_u}photo-1507003211169-0a1dd7228f2d?w=100';
  static const _a2 = '${_u}photo-1494790108377-be9c29b29330?w=100';

  static const _munnarTrip = Trip(
    id: 't1',
    title: 'Kochi to Munnar',
    coverUrl: _munnar,
    days: 2,
    stops: 8,
    distanceKm: 286,
    authorName: 'Arjun',
    authorAvatarUrl: _a1,
    likes: 1200,
    isFavorite: true,
  );
  static const _athirappilly = Trip(
    id: 't2',
    title: 'Athirappilly Day Trip',
    coverUrl: _falls,
    days: 1,
    stops: 6,
    distanceKm: 120,
    authorName: 'Sneha',
    authorAvatarUrl: _a2,
    likes: 856,
    isFavorite: true,
  );
  static const _wayanad = Trip(
    id: 't3',
    title: 'Wayanad Weekend',
    coverUrl: _tea,
    days: 3,
    stops: 10,
    distanceKm: 420,
    authorName: 'Rohit',
    authorAvatarUrl: _a1,
    likes: 640,
    isFavorite: true,
  );
  static const _food_ = Trip(
    id: 't4',
    title: 'Kozhikode Food Trail',
    coverUrl: _food,
    days: 1,
    stops: 8,
    distanceKm: 160,
    authorName: 'Neha',
    authorAvatarUrl: _a2,
    likes: 920,
    isFavorite: true,
  );

  Future<List<Trip>> trips(MyTripsTab tab) async => switch (tab) {
    MyTripsTab.saved => const [_munnarTrip, _athirappilly, _wayanad, _food_],
    MyTripsTab.mine => const [_athirappilly, _food_],
    MyTripsTab.liked => const [_munnarTrip, _wayanad, _food_],
  };
}
