import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/data/datasources/home_mock_datasource.dart';
import '../../features/home/data/datasources/places_remote_datasource.dart';
import '../../features/home/data/datasources/recent_places_local_datasource.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/trip_detail/data/datasources/trip_detail_mock_datasource.dart';
import '../../features/trip_detail/data/repositories/trip_detail_repository_impl.dart';
import '../../features/trip_detail/domain/repositories/trip_detail_repository.dart';
import '../../features/my_trips/data/datasources/my_trips_mock_datasource.dart';
import '../../features/my_trips/data/repositories/my_trips_repository_impl.dart';
import '../../features/my_trips/domain/repositories/my_trips_repository.dart';
import '../../features/notifications/data/datasources/notifications_mock_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/profile/data/datasources/profile_mock_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/trip_detail/data/datasources/routes_remote_datasource.dart';
import '../../features/trip_detail/data/repositories/route_repository_impl.dart';
import '../../features/trip_detail/domain/repositories/route_repository.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../network/dio_client.dart';
import '../services/location_service.dart';
import '../services/map_camera_cache.dart';
import '../services/marker_icon_builder.dart';
import '../storage/local_storage.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  sl
    ..registerLazySingleton<Dio>(createDioClient)
    ..registerLazySingleton(
      () => LocalStorage(prefs, const FlutterSecureStorage()),
    )
    ..registerLazySingleton(LocationService.new)
    ..registerLazySingleton(() => MapCameraCache(prefs))
    ..registerLazySingleton(() => MarkerIconBuilder(Dio()))
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(
        HomeMockDatasource(),
        PlacesRemoteDatasource(Dio()),
        RecentPlacesLocalDatasource(prefs),
      ),
    )
    ..registerLazySingleton<TripDetailRepository>(
      () => TripDetailRepositoryImpl(TripDetailMockDatasource()),
    )
    ..registerLazySingleton<RouteRepository>(
      () => RouteRepositoryImpl(RoutesRemoteDatasource(Dio())),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(AuthRemoteDatasource()),
    )
    ..registerLazySingleton<MyTripsRepository>(
      () => MyTripsRepositoryImpl(MyTripsMockDatasource()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(NotificationsMockDatasource()),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(ProfileMockDatasource()),
    );
}
