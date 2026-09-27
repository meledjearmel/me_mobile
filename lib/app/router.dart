import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/two_factor_screen.dart';
import '../features/content/presentation/content_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../core/push/push_target.dart';
import '../features/inbox/presentation/inbox_screen.dart';
import '../features/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  // Rafraîchit le routeur à chaque changement de session, ou quand une
  // notification tapée pose une cible en attente, pour que `redirect` se rejoue.
  final refresh = GoRouterRefreshStream(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (session.isLoading) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final loggedIn = session.value != null;
      final onAuthRoute = state.matchedLocation.startsWith('/login');

      if (!loggedIn) {
        return onAuthRoute ? null : '/login';
      }
      if (onAuthRoute || state.matchedLocation == '/') {
        // Une notification tapée avant la connexion (app relancée) ouvre la
        // boîte de réception plutôt que l'accueil.
        return ref.read(pendingPushTargetProvider) != null ? '/inbox' : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(notice: state.extra as String?),
        routes: [
          GoRoute(
            path: 'two-factor',
            builder: (context, state) => TwoFactorScreen(challenge: state.extra! as String),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/content', builder: (context, state) => const ContentScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (context, state) => const AccountScreen())]),
        ],
      ),
    ],
  );
});

/// Pont entre un `Stream`/état Riverpod et `Listenable`, tel qu'attendu par `refreshListenable`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(pendingPushTargetProvider, (_, _) => notifyListeners());
  }
}
