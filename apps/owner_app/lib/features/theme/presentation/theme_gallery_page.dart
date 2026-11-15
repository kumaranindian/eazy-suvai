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
import 'menu_theme_preview.dart';

/// Theme gallery (M05, FR-056): choose a predefined theme.
///
/// * compact: 2-column grid; "Preview" opens a full-screen phone preview;
/// * medium: 2-column grid beside a phone preview;
/// * expanded: 4-column grid beside a large phone preview.
///
/// Choosing saves to the draft (autosave). Premium themes carry a badge;
/// M10 locks the ones the plan does not include.
class ThemeGalleryPage extends ConsumerWidget {
  const ThemeGalleryPage({super.key});

  static const customizeKey = ValueKey('theme.customize');
  static const previewKey = ValueKey('theme.preview');
  static Key cardKey(String id) => ValueKey('theme.card.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the autosave and the local edits alive while the page is open.
    ref.watch(draftAutosaveProvider);
    ref.watch(themeDraftProvider);
    final l10n = AppLocalizations.of(context);
    final breakpoint = Breakpoint.of(context);
    final presets = ref.watch(themePresetsProvider);
    final choice = ref.watch(currentThemeChoiceProvider);

    final Widget body = presets.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        message: CoreLocalizations.of(context).messageForError(e),
        onRetry: () => ref.invalidate(themePresetsProvider),
      ),
      data: (all) {
        final visible = [
          for (final p in all)
            if (!p.retired || p.id == choice.themeId) p,
        ];
        if (visible.isEmpty) {
          return EmptyState(
            icon: Icons.palette_outlined,
            title: l10n.themeEmpty,
          );
        }
        final grid = _Grid(
          presets: visible,
          columns: breakpoint.isExpanded ? 4 : 2,
          selectedId: choice.themeId,
          onChoose: (p) => _choose(context, ref, p),
        );
        if (breakpoint.isCompact) {
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
            children: [
              const _CurrentThemeCard(showPreviewButton: true),
              const SizedBox(height: 16),
              grid,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.all(24),
                children: [
                  const _CurrentThemeCard(showPreviewButton: false),
                  const SizedBox(height: 16),
                  grid,
                ],
              ),
            ),
            SizedBox(
              width: breakpoint.isExpanded ? 380 : 300,
              child: const SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(0, 24, 24, 24),
                child: MenuThemePreview(),
              ),
            ),
          ],
        );
      },
    );

    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          ref.read(draftAutosaveProvider.notifier).flush(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.themeTitle),
          actions: [
            if (!breakpoint.isCompact)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 16),
                child: Center(child: SaveStatusIndicator()),
              ),
          ],
        ),
        body: body,
        bottomNavigationBar: breakpoint.isCompact ? const SaveBar() : null,
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    ThemePreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    final choice = ref.read(currentThemeChoiceProvider);
    if (choice.themeId == preset.id) return;
    if (!choice.settings.isEmpty) {
      final ok = await showConfirmDialog(
        context,
        title: l10n.themeReplaceTitle,
        message: l10n.themeReplaceBody(preset.name),
        confirmLabel: l10n.themeReplaceConfirm,
      );
      if (!ok) return;
    }
    ref.read(themeDraftProvider.notifier).choose(preset.id);
  }
}

/// Opens the phone preview full screen (compact layouts).
Future<void> showFullScreenPreview(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.themePreviewTitle),
              leading: IconButton(
                key: const ValueKey('theme.preview.close'),
                icon: const Icon(Icons.close),
                tooltip: l10n.themePreviewClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const MenuThemePreview(scaleToFit: false),
          );
        },
      ),
    );

/// The chosen theme with "Customize" (and "Preview" on phones).
class _CurrentThemeCard extends ConsumerWidget {
  const _CurrentThemeCard({required this.showPreviewButton});

  final bool showPreviewButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final choice = ref.watch(currentThemeChoiceProvider);
    final preset = ref.watch(currentPresetProvider);
    final title = preset == null
        ? l10n.themeNotChosen
        : (choice.settings.isEmpty
              ? preset.name
              : l10n.themeCustomizedName(preset.name));
    return Card.outlined(
      margin: EdgeInsetsDirectional.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.themeCurrent,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              preset == null ? l10n.themeChooseHint : l10n.themeCustomizeHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: ThemeGalleryPage.customizeKey,
                  onPressed: preset == null
                      ? null
                      : () => context.go(Routes.themeEditor),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.themeCustomize),
                ),
                if (showPreviewButton)
                  OutlinedButton.icon(
                    key: ThemeGalleryPage.previewKey,
                    onPressed: () => showFullScreenPreview(context),
                    icon: const Icon(Icons.phone_iphone),
                    label: Text(l10n.themePreview),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.presets,
    required this.columns,
    required this.selectedId,
    required this.onChoose,
  });

  final List<ThemePreset> presets;
  final int columns;
  final String? selectedId;
  final ValueChanged<ThemePreset> onChoose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in presets)
            SizedBox(
              width: width,
              child: ThemeCard(
                key: ThemeGalleryPage.cardKey(p.id),
                preset: p,
                selected: p.id == selectedId,
                onTap: () => onChoose(p),
              ),
            ),
        ],
      );
    },
  );
}

/// A theme in the gallery: a miniature of its colours and font, its name,
/// a "Premium" badge and a check when selected.
class ThemeCard extends ConsumerWidget {
  const ThemeCard({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = resolveMenuTheme(preset.tokens);
    final fonts = ref.watch(menuFontResolverProvider);
    final sample = fonts.style(
      t.font,
      theme.textTheme.titleMedium!.copyWith(
        color: t.textColor,
        fontWeight: FontWeight.w700,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: [
        preset.name,
        if (preset.premium) l10n.themePremium,
        if (selected) l10n.themeSelected,
      ].join(', '),
      excludeSemantics: true,
      child: Card.outlined(
        margin: EdgeInsetsDirectional.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Miniature: background, a primary band, two item cards.
              Container(
                height: 120,
                color: t.backgroundColor,
                padding: const EdgeInsetsDirectional.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 18, color: t.primaryColor),
                    const SizedBox(height: 6),
                    Text(
                      l10n.themeFontSample,
                      style: sample,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                    const Spacer(),
                    for (final i in [0, 1]) ...[
                      if (i == 1) const SizedBox(height: 4),
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: t.surfaceColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: t.borderColor),
                        ),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 4,
                                color: t.surfaceTextColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 16,
                              height: 4,
                              color: t.accentColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            t.font,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (preset.premium) ...[
                            const SizedBox(height: 4),
                            _PremiumBadge(label: l10n.themePremium),
                          ],
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: scheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
