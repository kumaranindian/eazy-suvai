import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/finishing_setup_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/home/presentation/dashboard_page.dart';
import '../features/home/presentation/plan_page.dart';
import '../features/menu/application/menu_state.dart';
import '../features/menu/presentation/menu_page.dart';
import '../features/menu/presentation/recently_deleted_page.dart';
import '../features/publishing/presentation/preview_page.dart';
import '../features/publishing/presentation/version_history_page.dart';
import '../features/qr/presentation/qr_share_page.dart';
import '../features/restaurant/presentation/menu_link_page.dart';
import '../features/restaurant/presentation/opening_hours_page.dart';
import '../features/restaurant/presentation/profile_page.dart';
import '../features/restaurant/presentation/regional_page.dart';
import '../features/restaurant/presentation/settings_page.dart';
import '../features/setup/presentation/setup_wizard_page.dart';
import '../features/shell/presentation/owner_shell.dart';
import '../features/theme/presentation/theme_editor_page.dart';
import '../features/theme/presentation/theme_gallery_page.dart';
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

  // M03: onboarding and restaurant settings.
  static const setup = '/setup';
  static const profile = '/settings/profile';
  static const hours = '/settings/hours';
  static const regional = '/settings/regional';
  static const menuLink = '/settings/menu-link';

  // M04: menu management.
  static const menuDeleted = '/menu/deleted';
  static String menuCategory(String id) => '/menu/category/$id';
  static String menuItem(String id) => '/menu/item/$id';
  static String menuNewItem([String? categoryId]) => categoryId == null
      ? '/menu/item/new'
      : '/menu/item/new?category=${Uri.encodeQueryComponent(categoryId)}';

  // M05: theme gallery and editor.
  static const theme = '/settings/theme';
  static const themeEditor = '/settings/theme/customize';

  /// Where "Upgrade" leads (M10 replaces the page).
  static const plan = '/settings/plan';

  // M06: draft preview (full screen) and version history.
  static const preview = '/preview';
  static const versions = '/settings/versions';
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
      // Draft preview: full screen, above the shell (M06).
      GoRoute(
        path: Routes.preview,
        builder: (context, state) => const PreviewPage(),
      ),
      // First-run wizard: full screen, outside the shell.
      GoRoute(
        path: Routes.setup,
        builder: (context, state) => const SetupWizardPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OwnerShell(
          navigationShell: shell,
          // Detail pages (for example /settings/profile) bring their own
          // app bar with a back button.
          showAppBar: state.uri.pathSegments.length <= 1,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.menu,
                builder: (context, state) => const MenuPage(),
                routes: [
                  GoRoute(
                    path: 'category/:cid',
                    builder: (context, state) => CategoryItemsPage(
                      categoryId: state.pathParameters['cid']!,
                    ),
                  ),
                  GoRoute(
                    path: 'deleted',
                    builder: (context, state) => const RecentlyDeletedPage(),
                  ),
                  // The item editor covers the navigation bar on phones.
                  GoRoute(
                    path: 'item/new',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => ItemEditorPage(
                      target: EditorTarget.create(
                        state.uri.queryParameters['category'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'item/:iid',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => ItemEditorPage(
                      target: EditorTarget.item(state.pathParameters['iid']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.share,
                builder: (context, state) => const QrSharePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfilePage(),
                  ),
                  GoRoute(
                    path: 'hours',
                    builder: (context, state) => const OpeningHoursPage(),
                  ),
                  GoRoute(
                    path: 'regional',
                    builder: (context, state) => const RegionalPage(),
                  ),
                  GoRoute(
                    path: 'menu-link',
                    builder: (context, state) => const MenuLinkPage(),
                  ),
                  GoRoute(
                    path: 'plan',
                    builder: (context, state) => const PlanPage(),
                  ),
                  GoRoute(
                    path: 'versions',
                    builder: (context, state) => const VersionHistoryPage(),
                  ),
                  GoRoute(
                    path: 'theme',
                    builder: (context, state) => const ThemeGalleryPage(),
                    routes: [
                      GoRoute(
                        path: 'customize',
                        builder: (context, state) => const ThemeEditorPage(),
                      ),
                    ],
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
