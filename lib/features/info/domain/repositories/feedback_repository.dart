import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/feedback.dart';

abstract interface class FeedbackRepository {
  Future<Either<Failure, Unit>> send(FeedbackMessage feedback);
}
