import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../restaurant/application/draft_autosave.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/theme_repository.dart';

/// The theme choice being edited: the chosen theme and the owner's
/// overrides (FR-055).
@immutable
class ThemeChoice {
  const ThemeChoice(this.themeId, this.settings);

  final String? themeId;
  final ThemeSettings settings;
}

/// Local theme edits on top of the restaurant document (M05).
///
/// Every change updates the state at once, so the preview follows without
/// waiting for Firestore, and is staged on [DraftAutosave] (1 s debounce,
/// "Saved" indicator). Null means "no local edits": the restaurant's stored
/// values are shown.
class ThemeDraft extends Notifier<ThemeChoice?> {
  @override
  ThemeChoice? build() => null;

  DraftAutosave get _autosave => ref.read(draftAutosaveProvider.notifier);

  /// Chooses a predefined theme and drops the overrides (they belonged to
  /// the previous theme).
  void choose(String themeId) {
    state = ThemeChoice(themeId, const ThemeSettings());
    _autosave
      ..stage(RestaurantFields.themeId, themeId)
      ..stage(RestaurantFields.themeSettings, const <String, Object>{});
  }

  /// Replaces the overrides of the current theme.
  void update(ThemeSettings settings) {
    final themeId =
        state?.themeId ?? ref.read(currentRestaurantProvider).value?.themeId;
    state = ThemeChoice(themeId, settings);
    _autosave.stage(RestaurantFields.themeSettings, settings.toMap());
  }
}

final themeDraftProvider =
    NotifierProvider.autoDispose<ThemeDraft, ThemeChoice?>(ThemeDraft.new);

/// The theme choice the screens show: local edits, else the restaurant's.
final currentThemeChoiceProvider = Provider.autoDispose<ThemeChoice>((ref) {
  final local = ref.watch(themeDraftProvider);
  if (local != null) return local;
  final r = ref.watch(currentRestaurantProvider).value;
  return ThemeChoice(r?.themeId, r?.themeSettings ?? const ThemeSettings());
});

/// The preset with [id], or null (not chosen, missing, or still loading).
ThemePreset? presetById(List<ThemePreset>? presets, String? id) =>
    id == null ? null : presets?.where((p) => p.id == id).firstOrNull;

/// The chosen preset (null when none is chosen or it no longer exists).
final currentPresetProvider = Provider.autoDispose<ThemePreset?>((ref) {
  final id = ref.watch(currentThemeChoiceProvider).themeId;
  return presetById(ref.watch(themePresetsProvider).value, id);
});

/// The colours the menu will use, contrast fixes included (FR-060).
final resolvedThemeProvider = Provider.autoDispose<ResolvedMenuTheme>((ref) {
  final choice = ref.watch(currentThemeChoiceProvider);
  final preset = ref.watch(currentPresetProvider);
  return resolveMenuTheme(preset?.tokens, choice.settings);
});
