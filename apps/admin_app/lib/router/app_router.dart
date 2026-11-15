import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/mfa_setup_page.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/audit/audit_log_page.dart';
import '../features/catalog/catalog_pages.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/restaurants/restaurant_detail_page.dart';
import '../features/restaurants/restaurants_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/presentation/admin_shell.dart';
import '../features/subscriptions/presentation/upgrade_requests_page.dart';
import 'auth_guard.dart';
import 'not_found_page.dart';

part 'app_router.g.dart';

/// Route paths. Later modules add their routes here.
abstract final class Routes {
  static const dashboard = '/';
  static const restaurants = '/restaurants';
  static const upgrades = '/upgrades';
  static const plans = '/plans';
  static const catalog = '/catalog';
  static const audit = '/audit';
  static String restaurant(String id) => '/restaurants/$id';
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
            (Routes.upgrades, AdminSection.upgrades),
            (Routes.plans, AdminSection.plans),
            (Routes.catalog, AdminSection.catalog),
            (Routes.audit, AdminSection.audit),
            (Routes.settings, AdminSection.settings),
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => switch (section) {
                    AdminSection.dashboard => const DashboardPage(),
                    AdminSection.restaurants => const RestaurantsPage(),
                    AdminSection.upgrades => const UpgradeRequestsPage(),
                    AdminSection.plans => const PlansPage(),
                    AdminSection.catalog => const CatalogPage(),
                    AdminSection.audit => AuditLogPage(
                      restaurantId: state.uri.queryParameters['restaurant'],
                    ),
                    AdminSection.settings => const SettingsPage(),
                  },
                  routes: [
                    if (section == AdminSection.restaurants)
                      GoRoute(
                        path: ':rid',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => RestaurantDetailPage(
                          restaurantId: state.pathParameters['rid']!,
                        ),
                      ),
                  ],
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
