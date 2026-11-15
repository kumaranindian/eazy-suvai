import 'package:flutter/material.dart';

import 'breakpoint.dart';

/// One top-level navigation destination.
class AppDestination {
  const AppDestination({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;

  final IconData icon;
  final IconData selectedIcon;

  /// Localized label. Also used as the semantics label.
  final String label;
}

/// App shell that switches navigation style by width (architecture §6):
///
/// * compact (< 600 px): bottom navigation bar
/// * medium (600–1023 px): navigation rail
/// * expanded (≥ 1024 px): 240 px side menu, content capped at 1200 px
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.sideMenuHeader,
    this.showAppBar = true,
    this.banner,
  }) : assert(destinations.length >= 2, 'Navigation needs 2+ destinations');

  static const bottomBarKey = ValueKey('responsive-scaffold-bottom-bar');
  static const railKey = ValueKey('responsive-scaffold-rail');
  static const sideMenuKey = ValueKey('responsive-scaffold-side-menu');

  final String title;
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  /// Shown at the top of the side menu (for example the logo).
  final Widget? sideMenuHeader;

  /// False when the page inside [body] brings its own app bar (for example
  /// a detail page with a back button).
  final bool showAppBar;

  /// A persistent strip (for example M06's "Unpublished changes" bar):
  /// above the bottom navigation on compact windows, at the top of the
  /// content area on wider ones. Null or a zero-size widget shows nothing.
  final Widget? banner;

  static const bannerKey = ValueKey('responsive-scaffold-banner');

  Widget _withBanner(Widget content) {
    final b = banner;
    if (b == null) return content;
    return Column(
      children: [
        KeyedSubtree(key: bannerKey, child: b),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromWidth(MediaQuery.sizeOf(context).width);
    final appBar = showAppBar
        ? AppBar(title: Text(title), actions: actions)
        : null;

    switch (breakpoint) {
      case Breakpoint.compact:
        return Scaffold(
          appBar: appBar,
          body: SafeArea(child: body),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner case final b?) KeyedSubtree(key: bannerKey, child: b),
              NavigationBar(
                key: bottomBarKey,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
            ],
          ),
        );
      case Breakpoint.medium:
        return Scaffold(
          appBar: appBar,
          floatingActionButton: floatingActionButton,
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  key: railKey,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _withBanner(body)),
              ],
            ),
          ),
        );
      case Breakpoint.expanded:
        return Scaffold(
          appBar: appBar,
          floatingActionButton: floatingActionButton,
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  key: sideMenuKey,
                  width: Breakpoint.sideMenuWidth,
                  child: _SideMenu(
                    header: sideMenuHeader,
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                    onSelected: onDestinationSelected,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Breakpoint.maxContentWidth,
                      ),
                      child: _withBanner(body),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.header,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Widget? header;
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 12,
                end: 12,
                bottom: 16,
              ),
              child: header,
            ),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 4),
              child: ListTile(
                minTileHeight: 48,
                selected: i == selectedIndex,
                selectedTileColor: scheme.secondaryContainer,
                selectedColor: scheme.onSecondaryContainer,
                shape: const StadiumBorder(),
                leading: Icon(
                  i == selectedIndex
                      ? destinations[i].selectedIcon
                      : destinations[i].icon,
                ),
                title: Text(destinations[i].label),
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}
