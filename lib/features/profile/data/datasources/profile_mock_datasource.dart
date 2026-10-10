import '../../domain/entities/user_profile.dart';

/// Sample data. Replace with a remote datasource when the backend exists.
class ProfileMockDatasource {
  Future<UserProfile> profile() async => const UserProfile(
    name: 'Arjun Mathew',
    username: '@arjun.travels',
    bio:
        'Weekend road tripper from Kochi. Chasing waterfalls, tea hills and good food.',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
    trips: 12,
    followers: 1480,
    following: 212,
  );
}
