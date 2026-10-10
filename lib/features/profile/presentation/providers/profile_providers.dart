import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';

final profileProvider = FutureProvider<UserProfile>((ref) async {
  final result = await GetProfile(sl<ProfileRepository>())();
  return result.fold((f) => throw Exception(f.message), (p) => p);
});
