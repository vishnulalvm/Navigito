import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_mock_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._mock);
  final ProfileMockDatasource _mock;

  @override
  Future<Either<Failure, UserProfile>> getProfile() async {
    try {
      return right(await _mock.profile());
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
