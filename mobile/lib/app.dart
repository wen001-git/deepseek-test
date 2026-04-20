import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/paywall_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/hot_trends_screen.dart';
import 'presentation/screens/feature_screens.dart';
import 'presentation/screens/account_planning_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// ChangeNotifier wrapper so GoRouter re-evaluates redirect on auth change
// without recreating the entire GoRouter instance.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final path = state.uri.path;

    // Stay on splash until init() sets isInitialized = true
    if (!auth.isInitialized) return path == '/splash' ? null : '/splash';

    // Once initialized, redirect away from splash
    if (path == '/splash') {
      return auth.isAuthenticated ? '/home' : '/login';
    }

    // All authenticated users can reach /home and feature screens.
    // Free-tier users are limited to 3 calls/day — the backend returns 429
    // when quota is exceeded, which is surfaced as an error in the UI.
    // The /paywall screen is reachable as an optional upgrade path from home.
    if (!auth.isAuthenticated) return '/login';
    if (path == '/hot-trends' && !auth.isAdmin) return '/home';

    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, _s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _s) => const LoginScreen()),
      GoRoute(path: '/paywall', builder: (_, _s) => const PaywallScreen()),
      GoRoute(path: '/home', builder: (_, _s) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (_, _s) => const ProfileScreen()),
      GoRoute(path: '/hot-trends', builder: (_, _s) => const HotTrendsScreen()),
      GoRoute(path: '/account-planning', builder: (_, _s) => const AccountPlanningScreen()),
      GoRoute(
        path: '/script',
        builder: (_, state) =>
            ScriptScreen(initialTopic: state.extra as String?),
      ),
      GoRoute(
        path: '/shot-table',
        builder: (_, state) =>
            ShotTableScreen(initialScript: state.extra as String?),
      ),
      GoRoute(path: '/positioning', builder: (_, _s) => const PositioningScreen()),
      GoRoute(path: '/viral-topics', builder: (_, _s) => const ViralTopicsScreen()),
      GoRoute(path: '/monetize-topics', builder: (_, _s) => const MonetizeTopicsScreen()),
      GoRoute(path: '/rewrite', builder: (_, _s) => const RewriteScreen()),
      GoRoute(path: '/breakdown', builder: (_, _s) => const BreakdownScreen()),
      GoRoute(path: '/imitate', builder: (_, _s) => const ImitateScreen()),
      GoRoute(path: '/search', builder: (_, _s) => const SearchViralScreen()),
      GoRoute(path: '/breakdown-sharetext', builder: (_, _s) => const BreakdownSharetextScreen()),
      GoRoute(path: '/director', builder: (_, _s) => const DirectorScreen()),
      GoRoute(path: '/content-plan', builder: (_, _s) => const ContentPlanScreen()),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Short Video AI',
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
