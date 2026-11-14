import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/sign_in_page.dart';
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
  static const signIn = '/sign-in';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    redirect: (context, state) => authGuard(ref, state),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInPage(),
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
