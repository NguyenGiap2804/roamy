import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'providers/category_provider.dart';
import 'providers/explore_provider.dart';
import 'providers/place_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/category_service.dart';
import 'services/google_places_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/place_service.dart';
import 'services/schedule_service.dart';

class RoamyApp extends StatelessWidget {
  const RoamyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        Provider<NotificationService>.value(
          value: NotificationService.instance,
        ),
        Provider<PlaceService>(
          create: (context) => PlaceService(context.read<ApiClient>()),
        ),
        Provider<CategoryService>(
          create: (context) => CategoryService(context.read<ApiClient>()),
        ),
        Provider<ScheduleService>(
          create: (context) => ScheduleService(context.read<ApiClient>()),
        ),
        // ── Explore System services ──
        Provider<LocationService>.value(value: LocationService.instance),
        Provider<ExploreApiService>(
          create: (_) => ExploreApiService(),
        ),
        // ── Providers ──
        ChangeNotifierProvider<PlaceProvider>(
          create: (context) => PlaceProvider(context.read<PlaceService>()),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (context) =>
              CategoryProvider(context.read<CategoryService>()),
        ),
        ChangeNotifierProvider<ScheduleProvider>(
          create: (context) => ScheduleProvider(
            context.read<ScheduleService>(),
            context.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<ExploreProvider>(
          create: (context) => ExploreProvider(
            context.read<ExploreApiService>(),
            context.read<LocationService>(),
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'RoaMy Place',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
