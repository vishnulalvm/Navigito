import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/add_trip/data/datasources/add_trip_remote_datasource.dart';
import '../../features/add_trip/data/repositories/add_trip_repository_impl.dart';
import '../../features/add_trip/domain/repositories/add_trip_repository.dart';
import '../../features/home/data/datasources/home_mock_datasource.dart';
import '../../features/journey/data/datasources/journey_local_datasource.dart';
import '../../features/journey/data/repositories/journey_repository_impl.dart';
import '../../features/journey/domain/repositories/journey_repository.dart';
import '../../features/info/data/datasources/feedback_remote_datasource.dart';
import '../../features/info/data/repositories/feedback_repository_impl.dart';
import '../../features/info/domain/repositories/feedback_repository.dart';
import '../../features/home/data/datasources/maps_link_remote_datasource.dart';
import '../../features/home/data/datasources/places_remote_datasource.dart';
import '../../features/home/data/datasources/recent_places_local_datasource.dart';
import '../../features/home/data/datasources/trip_social_remote_datasource.dart';
import '../../features/home/data/datasources/trips_remote_datasource.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/trip_detail/data/datasources/trip_comments_remote_datasource.dart';
import '../../features/trip_detail/data/datasources/trip_detail_remote_datasource.dart';
import '../../features/trip_detail/data/repositories/trip_detail_repository_impl.dart';
import '../../features/trip_detail/domain/repositories/trip_detail_repository.dart';
import '../../features/my_trips/data/datasources/my_trips_remote_datasource.dart';
import '../../features/my_trips/data/repositories/my_trips_repository_impl.dart';
import '../../features/my_trips/domain/repositories/my_trips_repository.dart';
import '../../features/notifications/data/datasources/notifications_mock_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
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
  // Likes, saves and follows are shared by home, trip detail and My Trips.
  final social = TripSocialRemoteDatasource();

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
        TripsRemoteDatasource(),
        social,
        PlacesRemoteDatasource(Dio()),
        MapsLinkRemoteDatasource(Dio()),
        RecentPlacesLocalDatasource(prefs),
      ),
    )
    ..registerLazySingleton<TripDetailRepository>(
      () => TripDetailRepositoryImpl(
        TripDetailRemoteDatasource(),
        social,
        TripCommentsRemoteDatasource(),
      ),
    )
    ..registerLazySingleton<RouteRepository>(
      () => RouteRepositoryImpl(RoutesRemoteDatasource(Dio())),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(AuthRemoteDatasource()),
    )
    ..registerLazySingleton<MyTripsRepository>(
      () => MyTripsRepositoryImpl(MyTripsRemoteDatasource()),
    )
    ..registerLazySingleton<AddTripRepository>(
      () => AddTripRepositoryImpl(AddTripRemoteDatasource()),
    )
    ..registerLazySingleton<JourneyRepository>(
      () => JourneyRepositoryImpl(JourneyLocalDatasource(prefs)),
    )
    ..registerLazySingleton<FeedbackRepository>(
      () => FeedbackRepositoryImpl(FeedbackRemoteDatasource()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(NotificationsMockDatasource()),
    );
}
