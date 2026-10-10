import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/repositories/trip_detail_repository.dart';
import '../../domain/usecases/get_trip_detail.dart';

class TripDetailNotifier extends FamilyAsyncNotifier<TripDetail, String> {
  @override
  Future<TripDetail> build(String arg) async {
    final result = await GetTripDetail(sl<TripDetailRepository>())(arg);
    return result.fold((f) => throw Exception(f.message), (d) => d);
  }

  void _update(TripDetail Function(TripDetail) fn) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(fn(current));
  }

  void toggleLike() => _update((d) => d.copyWith(isLiked: !d.isLiked));
  void toggleFollow() =>
      _update((d) => d.copyWith(isFollowing: !d.isFollowing));
  void toggleSave() => _update((d) => d.copyWith(isSaved: !d.isSaved));
}

final tripDetailProvider =
    AsyncNotifierProvider.family<TripDetailNotifier, TripDetail, String>(
      TripDetailNotifier.new,
    );
