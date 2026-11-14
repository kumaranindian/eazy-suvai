import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/owner_auth_service.dart';

/// Top-level sections of the owner app, in navigation order.
enum OwnerSection { home, menu, share, settings }

extension OwnerSectionView on OwnerSection {
  String label(AppLocalizations l10n) => switch (this) {
    OwnerSection.home => l10n.navHome,
    OwnerSection.menu => l10n.navMenu,
    OwnerSection.share => l10n.navShare,
    OwnerSection.settings => l10n.navSettings,
  };

  AppDestination destination(AppLocalizations l10n) => switch (this) {
    OwnerSection.home => AppDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: label(l10n),
    ),
    OwnerSection.menu => AppDestination(
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      label: label(l10n),
    ),
    OwnerSection.share => AppDestination(
      icon: Icons.qr_code_2_outlined,
      selectedIcon: Icons.qr_code_2,
      label: label(l10n),
    ),
    OwnerSection.settings => AppDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: label(l10n),
    ),
  };
}

/// The owner app shell: [ResponsiveScaffold] around the current branch.
class OwnerShell extends ConsumerWidget {
  const OwnerShell({
    super.key,
    required this.navigationShell,
    this.showAppBar = true,
  });

  final StatefulNavigationShell navigationShell;

  /// False on detail pages that have their own app bar.
  final bool showAppBar;

  static const signOutKey = ValueKey('shell.signOut');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final section = OwnerSection.values[navigationShell.currentIndex];
    return ResponsiveScaffold(
      title: section.label(l10n),
      showAppBar: showAppBar,
      actions: [
        AppIconButton(
          key: signOutKey,
          icon: Icons.logout,
          semanticLabel: l10n.actionSignOut,
          onPressed: () => ref.read(ownerAuthServiceProvider).signOut(),
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
      destinations: [for (final s in OwnerSection.values) s.destination(l10n)],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      body: navigationShell,
    );
  }
}
