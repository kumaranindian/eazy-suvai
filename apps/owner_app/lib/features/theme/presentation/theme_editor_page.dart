import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../restaurant/application/draft_autosave.dart';
import '../../restaurant/presentation/save_status.dart';
import '../application/theme_draft.dart';
import '../data/theme_repository.dart';
import 'color_field.dart';
import 'contrast_notice.dart';
import 'menu_theme_preview.dart';
import 'theme_gallery_page.dart';

/// Theme editor (M05, FR-055, FR-057, FR-060): colours, font, layouts and
/// light/dark mode on top of the chosen theme, with a live preview.
///
/// * compact: controls in a scrolling page; "Preview" opens the phone
///   preview full screen;
/// * medium: controls (360 px) beside a phone preview;
/// * expanded: controls (360 px) beside a phone or desktop preview.
///
/// Every change updates the preview at once and autosaves to the draft.
class ThemeEditorPage extends ConsumerStatefulWidget {
  const ThemeEditorPage({super.key});

  static const previewKey = ValueKey('themeEditor.preview');
  static const fontKey = ValueKey('themeEditor.font');
  static const darkModeKey = ValueKey('themeEditor.darkMode');
  static const resetAllKey = ValueKey('themeEditor.resetAll');
  static const deviceKey = ValueKey('themeEditor.device');
  static Key layoutKey(MenuLayout l) =>
      ValueKey('themeEditor.layout.${l.wire}');
  static Key cardKey(CardLayout c) => ValueKey('themeEditor.card.${c.wire}');

  @override
  ConsumerState<ThemeEditorPage> createState() => _ThemeEditorPageState();
}

class _ThemeEditorPageState extends ConsumerState<ThemeEditorPage> {
  PreviewDevice _device = PreviewDevice.phone;

  @override
  Widget build(BuildContext context) {
    ref.watch(draftAutosaveProvider);
    ref.watch(themeDraftProvider);
    final l10n = AppLocalizations.of(context);
    final breakpoint = Breakpoint.of(context);
    final presets = ref.watch(themePresetsProvider);
    final preset = ref.watch(currentPresetProvider);

    final Widget body;
    if (presets.isLoading) {
      body = const LoadingState();
    } else if (preset == null) {
      body = EmptyState(
        icon: Icons.palette_outlined,
        title: l10n.themeChooseFirst,
        actionLabel: l10n.themeChooseAction,
        onAction: () => context.go(Routes.theme),
      );
    } else {
      final controls = _Controls(preset: preset);
      body = switch (breakpoint) {
        Breakpoint.compact => SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          child: controls,
        ),
        _ => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 360,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 16, 24),
                child: controls,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _PreviewPane(
                device: breakpoint.isExpanded ? _device : PreviewDevice.phone,
                showToggle: breakpoint.isExpanded,
                onDevice: (d) => setState(() => _device = d),
              ),
            ),
          ],
        ),
      };
    }

    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          ref.read(draftAutosaveProvider.notifier).flush(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.themeEditorTitle),
          actions: [
            if (!breakpoint.isCompact)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 16),
                child: Center(child: SaveStatusIndicator()),
              )
            else if (preset != null)
              TextButton.icon(
                key: ThemeEditorPage.previewKey,
                onPressed: () => showFullScreenPreview(context),
                icon: const Icon(Icons.phone_iphone),
                label: Text(l10n.themePreview),
              ),
          ],
        ),
        body: body,
        bottomNavigationBar: breakpoint.isCompact ? const SaveBar() : null,
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.device,
    required this.showToggle,
    required this.onDevice,
  });

  final PreviewDevice device;
  final bool showToggle;
  final ValueChanged<PreviewDevice> onDevice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          children: [
            if (showToggle) ...[
              SegmentedButton<PreviewDevice>(
                key: ThemeEditorPage.deviceKey,
                segments: [
                  ButtonSegment(
                    value: PreviewDevice.phone,
                    icon: const Icon(Icons.phone_iphone),
                    label: Text(l10n.themeDevicePhone),
                  ),
                  ButtonSegment(
                    value: PreviewDevice.desktop,
                    icon: const Icon(Icons.desktop_windows_outlined),
                    label: Text(l10n.themeDeviceDesktop),
                  ),
                ],
                selected: {device},
                onSelectionChanged: (s) => onDevice(s.first),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Center(child: MenuThemePreview(device: device)),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.themePreviewNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.preset});

  final ThemePreset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(currentThemeChoiceProvider).settings;
    final resolved = ref.watch(resolvedThemeProvider);
    final fonts = ref.watch(menuFontsProvider);
    final fontResolver = ref.watch(menuFontResolverProvider);
    final draft = ref.read(themeDraftProvider.notifier);
    void update(ThemeSettings next) => draft.update(next);

    // A font no longer offered stays selectable for this restaurant.
    final fontChoices = [
      ...fonts,
      if (!fonts.contains(resolved.font)) resolved.font,
    ];

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.themeEditorBasedOn(preset.name),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        heading(l10n.themeSectionColours),
        ContrastNotice(theme: resolved),
        const SizedBox(height: 16),
        ColorField(
          id: 'primary',
          label: l10n.themePrimary,
          help: l10n.themePrimaryHelp,
          value: resolved.primary,
          overridden: s.primary != null,
          onChanged: (v) => update(s.copyWith(primary: () => v)),
        ),
        const SizedBox(height: 16),
        ColorField(
          id: 'secondary',
          label: l10n.themeSecondary,
          help: l10n.themeSecondaryHelp,
          value: resolved.secondary,
          overridden: s.secondary != null,
          onChanged: (v) => update(s.copyWith(secondary: () => v)),
        ),
        const SizedBox(height: 16),
        ColorField(
          id: 'background',
          label: l10n.themeBackground,
          help: l10n.themeBackgroundHelp,
          value: resolved.background,
          overridden: s.background != null,
          onChanged: (v) => update(s.copyWith(background: () => v)),
        ),
        const SizedBox(height: 16),
        heading(l10n.themeSectionFont),
        DropdownButtonFormField<String>(
          key: ThemeEditorPage.fontKey,
          value: resolved.font,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.themeFont),
          items: [
            for (final f in fontChoices)
              DropdownMenuItem(
                value: f,
                child: Text(
                  f,
                  style: fontResolver.style(
                    f,
                    theme.textTheme.bodyLarge ?? const TextStyle(),
                  ),
                ),
              ),
          ],
          onChanged: (f) => update(
            s.copyWith(font: () => f == preset.tokens.font ? null : f),
          ),
        ),
        const SizedBox(height: 16),
        heading(l10n.themeSectionLayout),
        Text(l10n.themeLayout, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<MenuLayout>(
          segments: [
            ButtonSegment(
              value: MenuLayout.list,
              icon: const Icon(Icons.view_agenda_outlined),
              label: Text(
                l10n.themeLayoutList,
                key: ThemeEditorPage.layoutKey(MenuLayout.list),
              ),
            ),
            ButtonSegment(
              value: MenuLayout.grid,
              icon: const Icon(Icons.grid_view),
              label: Text(
                l10n.themeLayoutGrid,
                key: ThemeEditorPage.layoutKey(MenuLayout.grid),
              ),
            ),
          ],
          selected: {resolved.layout},
          onSelectionChanged: (v) => update(
            s.copyWith(
              layout: () => v.first == preset.tokens.layout ? null : v.first,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.themeCardLayout, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        // Three options do not fit side by side at 360 px with labels, so
        // they are radio tiles.
        for (final c in CardLayout.values)
          RadioListTile<CardLayout>(
            key: ThemeEditorPage.cardKey(c),
            value: c,
            groupValue: resolved.cardLayout,
            onChanged: (v) {
              if (v == null) return;
              update(
                s.copyWith(
                  cardLayout: () => v == preset.tokens.cardLayout ? null : v,
                ),
              );
            },
            contentPadding: EdgeInsetsDirectional.zero,
            title: Text(_cardLabel(l10n, c)),
            secondary: Icon(_cardIcon(c)),
          ),
        const SizedBox(height: 8),
        heading(l10n.themeSectionMode),
        SwitchListTile(
          key: ThemeEditorPage.darkModeKey,
          contentPadding: EdgeInsetsDirectional.zero,
          title: Text(l10n.themeDarkMode),
          subtitle: Text(l10n.themeDarkModeHelp),
          value: resolved.mode == MenuMode.dark,
          onChanged: (dark) {
            final mode = dark ? MenuMode.dark : MenuMode.light;
            update(
              s.copyWith(mode: () => mode == preset.tokens.mode ? null : mode),
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: ThemeEditorPage.resetAllKey,
            onPressed: s.isEmpty ? null : () => update(const ThemeSettings()),
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.themeResetAll),
          ),
        ),
      ],
    );
  }

  static String _cardLabel(AppLocalizations l10n, CardLayout c) => switch (c) {
    CardLayout.compact => l10n.themeCardCompact,
    CardLayout.imageTop => l10n.themeCardImageTop,
    CardLayout.imageLeft => l10n.themeCardImageLeft,
  };

  static IconData _cardIcon(CardLayout c) => switch (c) {
    CardLayout.compact => Icons.view_headline,
    CardLayout.imageTop => Icons.crop_portrait,
    CardLayout.imageLeft => Icons.view_list_outlined,
  };
}
