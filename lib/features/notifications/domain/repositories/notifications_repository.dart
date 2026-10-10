import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationsRepository {
  Future<Either<Failure, List<AppNotification>>> getNotifications();
}
