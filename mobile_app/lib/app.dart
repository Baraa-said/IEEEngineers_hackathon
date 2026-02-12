import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/query_screen.dart';
import 'screens/map_screen.dart';
import 'screens/facilities_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/auth_provider.dart';

class SituationRoomApp extends ConsumerWidget {
  const SituationRoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Situation Room',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('en'),
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      initialRoute: authState.isAuthenticated ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/query': (context) => const QueryScreen(),
        '/map': (context) => const MapScreen(),
        '/facilities': (context) => const FacilitiesScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
