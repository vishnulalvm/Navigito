import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/constants/env.dart';
import 'core/di/injection.dart';
import 'core/services/map_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Runs alongside the rest of startup; must finish before the map is built.
  final mapSdk = initMapSdk();
  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }
  await configureDependencies();
  await mapSdk;
  runApp(const ProviderScope(child: App()));
}
