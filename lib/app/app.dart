import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/splash/presentation/widgets/splash_overlay.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(lightDynamic?.harmonized()),
        darkTheme: AppTheme.dark(darkDynamic?.harmonized()),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: AppRouter.router,
        builder: (context, child) =>
            SplashOverlay(child: child ?? const SizedBox()),
      ),
    );
  }
}
