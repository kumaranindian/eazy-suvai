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
    this.leading,
    this.footer,
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

  /// The brand (for example the logo). On expanded windows it sits in the
  /// start segment of the portal header, directly above the side menu.
  final Widget? sideMenuHeader;

  /// False when the page inside [body] brings its own app bar (for example
  /// a detail page with a back button).
  final bool showAppBar;

  /// A persistent strip (for example M06's "Unpublished changes" bar):
  /// above the bottom navigation on compact windows, at the top of the
  /// content area on wider ones. Null or a zero-size widget shows nothing.
  final Widget? banner;

  static const bannerKey = ValueKey('responsive-scaffold-banner');

  /// Shown before the title in the app bar (for example a back button on a
  /// detail page that stays inside the shell). Null keeps the default.
  final Widget? leading;

  /// A strip pinned under the content area on medium and expanded windows,
  /// so the navigation, app bar and footer stay put and only the content
  /// changes. Not shown on compact windows, where the bottom navigation
  /// takes that place.
  final Widget? footer;

  static const footerKey = ValueKey('responsive-scaffold-footer');

  /// The full-width portal header on expanded windows. Its start segment
  /// ([headerBrandKey]) is as wide as the side menu and holds
  /// [sideMenuHeader], so the brand sits above the navigation and the page
  /// title, back button and actions sit above the content.
  static const headerKey = ValueKey('responsive-scaffold-header');
  static const headerBrandKey = ValueKey('responsive-scaffold-header-brand');

  /// Height of the expanded-window portal header.
  static const double headerHeight = 64;

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

  Widget _withFooter(Widget content) {
    final f = footer;
    if (f == null) return content;
    return Column(
      children: [
        Expanded(child: content),
        KeyedSubtree(key: footerKey, child: f),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromWidth(MediaQuery.sizeOf(context).width);
    final appBar = showAppBar
        ? AppBar(
            leading: leading,
            automaticallyImplyLeading: leading == null,
            title: Text(title),
            actions: actions,
          )
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
                Expanded(child: _withFooter(_withBanner(body))),
              ],
            ),
          ),
        );
      case Breakpoint.expanded:
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          floatingActionButton: floatingActionButton,
          body: SafeArea(
            child: Column(
              children: [
                // Portal header: brand segment over the side menu, page
                // header over the content. Same on every page.
                SizedBox(
                  key: headerKey,
                  height: headerHeight,
                  child: Row(
                    children: [
                      Material(
                        key: headerBrandKey,
                        color: scheme.surfaceContainerLow,
                        child: SizedBox(
                          width: Breakpoint.sideMenuWidth,
                          height: headerHeight,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: sideMenuHeader,
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: showAppBar
                            ? AppBar(
                                primary: false,
                                toolbarHeight: headerHeight,
                                leading: leading,
                                automaticallyImplyLeading: leading == null,
                                // Same colour as the brand segment, so the
                                // header reads as one strip.
                                backgroundColor: scheme.surfaceContainerLow,
                                surfaceTintColor: Colors.transparent,
                                scrolledUnderElevation: 0,
                                title: Text(title),
                                actions: actions,
                              )
                            : ColoredBox(color: scheme.surfaceContainerLow),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        key: sideMenuKey,
                        width: Breakpoint.sideMenuWidth,
                        child: _SideMenu(
                          destinations: destinations,
                          selectedIndex: selectedIndex,
                          onSelected: onDestinationSelected,
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: _withFooter(
                          Align(
                            alignment: AlignmentDirectional.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: Breakpoint.maxContentWidth,
                              ),
                              child: _withBanner(body),
                            ),
                          ),
                        ),
                      ),
                    ],
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
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

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
