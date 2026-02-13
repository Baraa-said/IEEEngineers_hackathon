import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/query_screen.dart';
import 'screens/map_screen.dart';
import 'screens/facilities_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';

/// Smooth slide+fade page transition
class _SlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  _SlideRoute({required this.page, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, anim, __, child) {
            final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curve),
                child: child,
              ),
            );
          },
        );
}

class SituationRoomApp extends ConsumerWidget {
  const SituationRoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);

    return MaterialApp(
      title: 'Aid NAV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: authState.isAuthenticated ? const HomeScreen() : const LoginScreen(),
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/query': (_) => const QueryScreen(),
          '/map': (_) => const MapScreen(),
          '/facilities': (_) => const FacilitiesScreen(),
          '/settings': (_) => const SettingsScreen(),
        };
        final builder = routes[settings.name];
        if (builder != null) {
          return _SlideRoute(page: builder(context), settings: settings);
        }
        return null;
      },
    );
  }
}
