import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/feedback.dart';
import '../repositories/feedback_repository.dart';

class SendFeedback {
  const SendFeedback(this._repository);
  final FeedbackRepository _repository;

  Future<Either<Failure, Unit>> call(FeedbackMessage feedback) =>
      _repository.send(feedback);
}
