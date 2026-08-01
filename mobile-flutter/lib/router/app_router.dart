import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/board/board_screen.dart';
import '../features/shell/home_shell.dart';

/// Bridges Riverpod's [authControllerProvider] to go_router's
/// `refreshListenable` - go_router only re-evaluates `redirect` on
/// navigation or when this notifies, so a sign-in/sign-out that happens
/// without a navigation event (e.g. the splash-screen session bootstrap
/// resolving) still re-runs the redirect logic below.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/board', builder: (context, state) => const BoardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// This app has no anonymous/guest session and no public read - every role
/// (including viewer) must be a real, signed-in account, and there is no
/// registration screen (see `plan/build-plan.md` "Auth Model"), so the only
/// non-shell destination is `/login`.
String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authControllerProvider);
  final location = state.matchedLocation;
  final isAuthRoute = location == '/login';

  if (authState.isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  final user = authState.valueOrNull;
  if (user == null) {
    return isAuthRoute ? null : '/login';
  }

  if (isAuthRoute || location == '/splash') {
    return '/board';
  }

  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
