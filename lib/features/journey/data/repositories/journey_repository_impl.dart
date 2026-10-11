import '../../domain/entities/journey_progress.dart';
import '../../domain/repositories/journey_repository.dart';
import '../datasources/journey_local_datasource.dart';

class JourneyRepositoryImpl implements JourneyRepository {
  JourneyRepositoryImpl(this._local);
  final JourneyLocalDatasource _local;

  @override
  JourneyProgress? read(String tripId) => _local.read(tripId);

  @override
  Future<void> save(JourneyProgress progress) => _local.save(progress);

  @override
  Future<void> clear(String tripId) => _local.clear(tripId);
}
