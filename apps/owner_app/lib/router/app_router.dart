import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/finishing_setup_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/dev/presentation/media_test_page.dart';
import '../features/home/presentation/placeholder_page.dart';
import '../features/shell/presentation/owner_shell.dart';
import 'auth_guard.dart';
import 'not_found_page.dart';

part 'app_router.g.dart';

/// Route paths. Later modules add their routes here.
abstract final class Routes {
  static const home = '/';
  static const menu = '/menu';
  static const share = '/share';
  static const settings = '/settings';

  // M01: account screens.
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const finishingSetup = '/finishing-setup';
  static const splash = '/splash';

  /// M02 developer page to try image uploads. Not registered in prod.
  static const devMedia = '/dev/media';
}

/// Account screens switch without a transition. The guard can move a user
/// out of the shell and straight back (for example while claims refresh);
/// an animated exit would keep two copies of the shell alive at once.
Page<void> _instant(GoRouterState state, Widget child) =>
    NoTransitionPage(key: state.pageKey, child: child);

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
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
        pageBuilder: (context, state) => _instant(state, const SignInPage()),
      ),
      GoRoute(
        path: Routes.signUp,
        pageBuilder: (context, state) => _instant(state, const SignUpPage()),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        pageBuilder: (context, state) => _instant(
          state,
          VerifyEmailPage(
            email: state.uri.queryParameters['email'],
            reason: state.uri.queryParameters['reason'],
          ),
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        pageBuilder: (context, state) => _instant(
          state,
          ForgotPasswordPage(email: state.uri.queryParameters['email']),
        ),
      ),
      GoRoute(
        path: Routes.finishingSetup,
        pageBuilder: (context, state) =>
            _instant(state, const FinishingSetupPage()),
      ),
      if (!AppEnv.fromDefines().isProd)
        GoRoute(
          path: Routes.devMedia,
          builder: (context, state) => const MediaTestPage(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OwnerShell(navigationShell: shell),
        branches: [
          for (final (path, section) in const [
            (Routes.home, OwnerSection.home),
            (Routes.menu, OwnerSection.menu),
            (Routes.share, OwnerSection.share),
            (Routes.settings, OwnerSection.settings),
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
