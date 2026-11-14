import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/mfa_setup_page.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/home/presentation/placeholder_page.dart';
import '../features/shell/presentation/admin_shell.dart';
import 'auth_guard.dart';
import 'not_found_page.dart';

part 'app_router.g.dart';

/// Route paths. Later modules add their routes here.
abstract final class Routes {
  static const dashboard = '/';
  static const restaurants = '/restaurants';
  static const plans = '/plans';
  static const settings = '/settings';

  // M01: separate admin login with TOTP (FR-084).
  static const signIn = '/sign-in';
  static const mfaSetup = '/mfa-setup';
  static const splash = '/splash';
}

/// Account screens switch without a transition (see the owner app router).
Page<void> _instant(GoRouterState state, Widget child) =>
    NoTransitionPage(key: state.pageKey, child: child);

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.dashboard,
    refreshListenable: authRefreshListenable(ref),
    redirect: (context, state) => authGuard(ref, state),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) =>
            _instant(state, const Scaffold(body: LoadingState())),
      ),
      GoRoute(
        path: Routes.signIn,
        pageBuilder: (context, state) => _instant(
          state,
          SignInPage(enrolled: state.uri.queryParameters['enrolled'] == '1'),
        ),
      ),
      GoRoute(
        path: Routes.mfaSetup,
        pageBuilder: (context, state) => _instant(state, const MfaSetupPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdminShell(navigationShell: shell),
        branches: [
          for (final (path, section) in const [
            (Routes.dashboard, AdminSection.dashboard),
            (Routes.restaurants, AdminSection.restaurants),
            (Routes.plans, AdminSection.plans),
            (Routes.settings, AdminSection.settings),
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) =>
                      PlaceholderPage(section: section),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
