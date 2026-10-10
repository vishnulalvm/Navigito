import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_mock_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._mock);
  final NotificationsMockDatasource _mock;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications() async {
    try {
      return right(await _mock.notifications());
    } catch (_) {
      return left(const ServerFailure());
    }
  }
}
