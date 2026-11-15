import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../menu/application/menu_state.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../application/theme_draft.dart';

/// Which screen size the preview imitates (FR-057).
enum PreviewDevice {
  phone(Size(390, 780)),
  desktop(Size(1280, 800));

  const PreviewDevice(this.size);

  /// The logical size the menu is laid out at before scaling to fit.
  final Size size;
}

/// One category of the preview with the items it shows.
typedef PreviewSection = ({MenuCategory category, List<MenuItem> items});

/// What the preview shows: the owner's menu, or a sample while it is empty.
@immutable
class PreviewMenu {
  const PreviewMenu(this.sections, {required this.isSample});

  final List<PreviewSection> sections;
  final bool isSample;
}

/// The owner's live menu as the public page would list it (active
/// categories, items not hidden over the plan limit), or a sample menu
/// when there are no items yet.
PreviewMenu previewMenuOf(MenuData? data, AppLocalizations l10n) {
  final sections = <PreviewSection>[
    if (data != null)
      for (final c in data.categories)
        if (c.active)
          (
            category: c,
            items: [
              for (final i in data.itemsIn(c.id))
                if (!i.hiddenOverLimit) i,
            ],
          ),
  ].where((s) => s.items.isNotEmpty).toList();
  if (sections.isNotEmpty) return PreviewMenu(sections, isSample: false);

  MenuItem item(
    String id,
    String cat,
    String name,
    String desc,
    int price,
    String label, {
    bool available = true,
  }) => MenuItem(
    id: id,
    categoryId: cat,
    name: name,
    description: desc,
    priceMinor: price,
    dietaryLabelId: label,
    available: available,
  );
  return PreviewMenu([
    (
      category: MenuCategory(id: 's1', name: l10n.sampleStarters),
      items: [
        item(
          's1a',
          's1',
          l10n.sampleItemPaneer,
          l10n.sampleItemPaneerDesc,
          24000,
          'vegetarian',
        ),
        item(
          's1b',
          's1',
          l10n.sampleItemChicken,
          l10n.sampleItemChickenDesc,
          28000,
          'non-vegetarian',
          available: false,
        ),
      ],
    ),
    (
      category: MenuCategory(id: 's2', name: l10n.sampleMains),
      items: [
        item(
          's2a',
          's2',
          l10n.sampleItemDosa,
          l10n.sampleItemDosaDesc,
          12000,
          'vegetarian',
        ),
        item(
          's2b',
          's2',
          l10n.sampleItemBiryani,
          l10n.sampleItemBiryaniDesc,
          22000,
          'vegan',
        ),
      ],
    ),
  ], isSample: true);
}

/// Live preview of the public menu with the chosen theme (M05, FR-057).
///
/// A Flutter imitation of the M07 page built from the same resolved tokens
/// ([ResolvedMenuTheme]); the exact page is checked in the M06 preview.
/// Laid out at [device]'s size and scaled to fit, unless [scaleToFit] is
/// false (the full-screen phone preview), where it fills the space given.
class MenuThemePreview extends ConsumerWidget {
  const MenuThemePreview({
    super.key,
    this.device = PreviewDevice.phone,
    this.scaleToFit = true,
    this.theme,
  });

  final PreviewDevice device;
  final bool scaleToFit;

  /// Overrides the current resolved theme (theme cards in the gallery).
  final ResolvedMenuTheme? theme;

  static const canvasKey = ValueKey('themePreview.canvas');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ResolvedMenuTheme t = theme ?? ref.watch(resolvedThemeProvider);
    final restaurant = ref.watch(currentRestaurantProvider).value;
    final menu = previewMenuOf(ref.watch(menuDataProvider).value, l10n);
    final labels = {
      for (final l
          in ref.watch(dietaryLabelsProvider).value ?? const <MenuLabel>[])
        l.id: l,
    };
    final fonts = ref.watch(menuFontResolverProvider);

    final base = ThemeData(
      useMaterial3: true,
      brightness: t.mode == MenuMode.dark ? Brightness.dark : Brightness.light,
    );
    final textTheme = fonts
        .textTheme(t.font, base.textTheme)
        .apply(bodyColor: t.textColor, displayColor: t.textColor);
    final data = base.copyWith(
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: t.primaryColor,
        onPrimary: t.onPrimaryColor,
        secondary: t.secondaryColor,
        onSecondary: t.onSecondaryColor,
        surface: t.surfaceColor,
        onSurface: t.surfaceTextColor,
      ),
    );

    final page = Theme(
      data: data,
      child: Material(
        key: canvasKey,
        color: t.backgroundColor,
        child: DefaultTextStyle(
          style: textTheme.bodyMedium!,
          child: _MenuPage(
            theme: t,
            restaurant: restaurant,
            menu: menu,
            labels: labels,
            device: device,
          ),
        ),
      ),
    );

    final framed = scaleToFit
        ? AspectRatio(
            aspectRatio: device.size.width / device.size.height,
            child: FittedBox(
              child: SizedBox.fromSize(size: device.size, child: page),
            ),
          )
        : page;

    return Semantics(
      container: true,
      label: l10n.themePreviewTitle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(scaleToFit ? 16 : 0),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: scaleToFit
                ? Border.all(color: Theme.of(context).colorScheme.outline)
                : null,
            borderRadius: BorderRadius.circular(scaleToFit ? 16 : 0),
          ),
          child: framed,
        ),
      ),
    );
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage({
    required this.theme,
    required this.restaurant,
    required this.menu,
    required this.labels,
    required this.device,
  });

  final ResolvedMenuTheme theme;
  final Restaurant? restaurant;
  final PreviewMenu menu;
  final Map<String, MenuLabel> labels;
  final PreviewDevice device;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final t = theme;
    final r = restaurant;
    final wide = device == PreviewDevice.desktop;
    final grid = t.layout == MenuLayout.grid;
    final columns = grid ? (wide ? 4 : 2) : 1;
    final currency = r?.currency.isNotEmpty == true ? r!.currency : 'INR';

    String price(int minor) {
      try {
        return Money(minor, currency).format();
      } on ArgumentError {
        return '$minor';
      }
    }

    return CustomScrollView(
      primary: false,
      slivers: [
        SliverToBoxAdapter(
          child: _Header(theme: t, restaurant: r, wide: wide),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              children: [
                for (final (i, s) in menu.sections.indexed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _Pill(
                      label: s.category.name,
                      background: i == 0 ? t.primaryColor : t.surfaceColor,
                      foreground: i == 0
                          ? t.onPrimaryColor
                          : t.surfaceTextColor,
                      border: t.borderColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (menu.isSample)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Text(
                l10n.themePreviewSample,
                style: text.bodySmall?.copyWith(color: t.mutedTextColor),
              ),
            ),
          ),
        for (final s in menu.sections) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(
                s.category.name,
                style: text.titleLarge?.copyWith(
                  color: t.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                for (final item in s.items)
                  _ItemCard(
                    item: item,
                    theme: t,
                    label: labels[item.dietaryLabelId],
                    price: price(item.priceMinor),
                    inGrid: grid,
                  ),
              ];
              // List: one column of natural-height cards, at most 760 px
              // wide. Grid: fixed columns; the cell height follows the
              // cell width (image-top cards have a 4:3 image).
              final width = constraints.crossAxisExtent;
              final side = grid ? 16.0 : math.max(16.0, (width - 760) / 2);
              final cellWidth = (width - 32 - 12 * (columns - 1)) / columns;
              return SliverPadding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: side),
                sliver: grid
                    ? SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: _gridCellHeight(t, cellWidth),
                        ),
                        delegate: SliverChildListDelegate(cards),
                      )
                    : SliverList.separated(
                        itemCount: cards.length,
                        itemBuilder: (context, i) => cards[i],
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: 12),
                      ),
              );
            },
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// Room for the details (name, one line of description, price and a
  /// sold-out badge) plus the image. Taller fonts are clipped, not
  /// overflowing; the exact page is M07's.
  static double _gridCellHeight(ResolvedMenuTheme t, double cellWidth) =>
      switch (t.cardLayout) {
        CardLayout.compact || CardLayout.imageLeft => 150,
        CardLayout.imageTop => (cellWidth - 24) * 3 / 4 + 150,
      };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.restaurant,
    required this.wide,
  });

  final ResolvedMenuTheme theme;
  final Restaurant? restaurant;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final t = theme;
    final r = restaurant;
    final name = r == null || r.name.trim().isEmpty
        ? l10n.previewNoName
        : r.name;
    final coverHeight = wide ? 200.0 : 140.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: coverHeight + 44,
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                end: 0,
                top: 0,
                height: coverHeight,
                child: ColoredBox(
                  color: t.primaryColor,
                  child: r?.cover == null
                      ? const SizedBox.expand()
                      : ResponsiveImage(
                          image: r!.cover,
                          semanticLabel: l10n.fieldCover,
                        ),
                ),
              ),
              PositionedDirectional(
                start: 16,
                top: coverHeight - 44,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surfaceColor,
                    border: Border.all(color: t.backgroundColor, width: 4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ResponsiveImage(
                    image: r?.logo,
                    semanticLabel: l10n.fieldLogo,
                    placeholderIcon: Icons.storefront_outlined,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: text.headlineSmall?.copyWith(
                  color: t.textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (r != null && r.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  r.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: t.mutedTextColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: foreground),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.theme,
    required this.label,
    required this.price,
    required this.inGrid,
  });

  final MenuItem item;
  final ResolvedMenuTheme theme;
  final MenuLabel? label;
  final String price;

  /// In a grid cell of fixed height: smaller side image, one line of
  /// description, and anything taller is clipped.
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final t = theme;
    final soldOut = !item.available;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: t.secondaryColor,
        child: item.image == null
            ? Center(child: Icon(Icons.restaurant, color: t.onSecondaryColor))
            : ResponsiveImage(image: item.image, semanticLabel: item.name),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (label != null) ...[
              MenuLabelIcon(label: label!, size: 16),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  color: t.surfaceTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.description,
            maxLines: inGrid ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: t.mutedTextColor),
          ),
        ],
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              price,
              style: text.titleSmall?.copyWith(
                color: t.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (soldOut)
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: t.surfaceTextColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.themePreviewSoldOut,
                  style: text.labelSmall?.copyWith(color: t.surfaceColor),
                ),
              ),
          ],
        ),
      ],
    );

    final content = switch (t.cardLayout) {
      CardLayout.compact => details,
      CardLayout.imageLeft => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(dimension: inGrid ? 48 : 88, child: image),
          SizedBox(width: inGrid ? 8 : 12),
          Expanded(child: details),
        ],
      ),
      CardLayout.imageTop => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(aspectRatio: inGrid ? 4 / 3 : 16 / 9, child: image),
          const SizedBox(height: 8),
          details,
        ],
      ),
    };

    // Sold-out cards are not dimmed: that would take the text below AA.
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: t.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.borderColor),
      ),
      // A grid cell has a fixed height: lay the card out at its natural
      // height and clip what does not fit, instead of overflowing.
      child: inGrid
          ? ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.topStart,
                minHeight: 0,
                maxHeight: double.infinity,
                child: content,
              ),
            )
          : content,
    );
  }
}
