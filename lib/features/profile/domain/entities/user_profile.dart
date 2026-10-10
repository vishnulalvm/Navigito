import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.name,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.trips,
    required this.followers,
    required this.following,
  });

  final String name;
  final String username;
  final String bio;
  final String avatarUrl;
  final int trips;
  final int followers;
  final int following;

  @override
  List<Object?> get props => [username];
}
