import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/admin_auth_service.dart';

/// Top-level sections of the admin app, in navigation order.
enum AdminSection {
  dashboard,
  restaurants,
  upgrades,
  plans,
  catalog,
  audit,
  settings,
}

extension AdminSectionView on AdminSection {
  String label(AppLocalizations l10n) => switch (this) {
    AdminSection.dashboard => l10n.navDashboard,
    AdminSection.restaurants => l10n.navRestaurants,
    AdminSection.upgrades => l10n.navUpgrades,
    AdminSection.plans => l10n.navPlans,
    AdminSection.catalog => l10n.navCatalog,
    AdminSection.audit => l10n.navAudit,
    AdminSection.settings => l10n.navSettings,
  };

  AppDestination destination(AppLocalizations l10n) => switch (this) {
    AdminSection.dashboard => AppDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: label(l10n),
    ),
    AdminSection.restaurants => AppDestination(
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
      label: label(l10n),
    ),
    AdminSection.upgrades => AppDestination(
      icon: Icons.upgrade_outlined,
      selectedIcon: Icons.upgrade,
      label: label(l10n),
    ),
    AdminSection.plans => AppDestination(
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium,
      label: label(l10n),
    ),
    AdminSection.catalog => AppDestination(
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
      label: label(l10n),
    ),
    AdminSection.audit => AppDestination(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: label(l10n),
    ),
    AdminSection.settings => AppDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: label(l10n),
    ),
  };
}

/// The admin app shell: [ResponsiveScaffold] around the current branch.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const signOutKey = ValueKey('shell.signOut');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final section = AdminSection.values[navigationShell.currentIndex];
    return ResponsiveScaffold(
      title: section.label(l10n),
      actions: [
        AppIconButton(
          key: signOutKey,
          icon: Icons.logout,
          semanticLabel: l10n.actionSignOut,
          onPressed: () => ref.read(adminAuthServiceProvider).signOut(),
        ),
      ],
      sideMenuHeader: Image.asset(
        Theme.of(context).brightness == Brightness.dark
            ? 'assets/brand/logo_dark.png'
            : 'assets/brand/logo.png',
        height: 64,
        alignment: AlignmentDirectional.centerStart,
        semanticLabel: l10n.appTitle,
      ),
      destinations: [for (final s in AdminSection.values) s.destination(l10n)],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      body: navigationShell,
    );
  }
}
