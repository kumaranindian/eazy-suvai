import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../menu/application/menu_state.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/plan_repository.dart';

/// Keys, for tests.
abstract final class HiddenKeys {
  static const save = ValueKey('hidden.save');
  static const over = ValueKey('hidden.over');
  static const visibleList = ValueKey('hidden.visible');
  static const hiddenList = ValueKey('hidden.hidden');
  static ValueKey<String> toggle(String id) => ValueKey('hidden.toggle.$id');
}

/// The over-limit manager (FR-101, M10).
///
/// - Swap (default): choose which items and categories customers see within
///   the current plan; saving is a draft change, then the owner publishes.
/// - Downgrade (`downgrade: true`, from "Switch to Free"): choose what stays
///   visible on Free, then confirm; the plan switches and the menu is
///   published at once.
///
/// Compact: one list with a switch per entry. Expanded: "Visible" and
/// "Hidden" side by side with a move button on each row.
class HiddenContentPage extends ConsumerStatefulWidget {
  const HiddenContentPage({super.key, this.downgrade = false});

  final bool downgrade;

  @override
  ConsumerState<HiddenContentPage> createState() => _HiddenContentPageState();
}

class _HiddenContentPageState extends ConsumerState<HiddenContentPage> {
  /// Local choices: id → hidden.
  final _items = <String, bool>{};
  final _cats = <String, bool>{};
  bool _saving = false;

  bool _isHiddenItem(MenuItem i) => _items[i.id] ?? i.hiddenOverLimit;
  bool _isHiddenCat(MenuCategory c) => _cats[c.id] ?? c.hiddenOverLimit;

  Future<void> _save(Restaurant r, MenuData menu) async {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    if (widget.downgrade) {
      final ok = await showConfirmDialog(
        context,
        title: l10n.hiddenDowngradeConfirmTitle,
        message: l10n.hiddenDowngradeConfirmBody,
        confirmLabel: l10n.hiddenConfirmDowngrade,
      );
      if (!ok || !mounted) return;
    }
    List<String> diff(
      Map<String, bool> m,
      bool want,
      Map<String, bool> original,
    ) => [
      for (final e in m.entries)
        if (e.value == want && original[e.key] != want) e.key,
    ];
    final origItems = {for (final i in menu.items) i.id: i.hiddenOverLimit};
    final origCats = {for (final c in menu.categories) c.id: c.hiddenOverLimit};
    setState(() => _saving = true);
    try {
      await ref
          .read(planRepositoryProvider)
          .setHidden(
            r.id,
            hideItemIds: diff(_items, true, origItems),
            showItemIds: diff(_items, false, origItems),
            hideCategoryIds: diff(_cats, true, origCats),
            showCategoryIds: diff(_cats, false, origCats),
            downgrade: widget.downgrade,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.downgrade ? l10n.hiddenDowngraded : l10n.hiddenSaved,
          ),
        ),
      );
      context.go(Routes.plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(core.messageForError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final r = ref.watch(currentRestaurantProvider).value;
    final menu = ref.watch(menuDataProvider);
    final plans = ref.watch(plansProvider).value ?? fallbackPlans;
    final breakpoint = Breakpoint.of(context);
    final limits = widget.downgrade
        ? (plans.where((p) => p.isFree).firstOrNull?.features ??
              PlanFeatures.free)
        : (r?.planFeatures ?? PlanFeatures.free);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.downgrade ? l10n.hiddenDowngradeTitle : l10n.hiddenTitle,
        ),
      ),
      body: r == null
          ? const LoadingState()
          : menu.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: core.messageForError(e)),
              data: (m) {
                final visibleItems = m.items
                    .where((i) => !_isHiddenItem(i))
                    .length;
                final visibleCats = m.categories
                    .where((c) => !_isHiddenCat(c))
                    .length;
                final maxItems = limits.maxItems;
                final maxCats = limits.maxCategories;
                final overBy = [
                  if (maxItems != null) visibleItems - maxItems,
                  if (maxCats != null) visibleCats - maxCats,
                ].fold<int>(0, (a, b) => b > a ? b : a);
                final intro = widget.downgrade
                    ? l10n.hiddenDowngradeIntro(maxItems ?? 0, maxCats ?? 0)
                    : l10n.hiddenIntro(
                        isUnlimited(maxItems)
                            ? l10n.planUnlimited
                            : '$maxItems',
                      );

                Widget tile({
                  required String id,
                  required String title,
                  String? subtitle,
                  required bool hidden,
                  required ValueChanged<bool> onHidden,
                }) {
                  if (!breakpoint.isExpanded) {
                    return SwitchListTile(
                      key: HiddenKeys.toggle(id),
                      title: Text(title),
                      subtitle: subtitle == null ? null : Text(subtitle),
                      value: !hidden,
                      onChanged: (v) => onHidden(!v),
                    );
                  }
                  return ListTile(
                    title: Text(title),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    trailing: AppIconButton(
                      key: HiddenKeys.toggle(id),
                      icon: hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      semanticLabel: hidden
                          ? l10n.hiddenShow(title)
                          : l10n.hiddenHide(title),
                      onPressed: () => onHidden(!hidden),
                    ),
                  );
                }

                final catName = {for (final c in m.categories) c.id: c.name};
                Widget section(bool hiddenSide) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (m.categories.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          8,
                          16,
                          0,
                        ),
                        child: Text(
                          l10n.hiddenCategories,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final c in m.categories)
                        if (!breakpoint.isExpanded ||
                            _isHiddenCat(c) == hiddenSide)
                          tile(
                            id: 'c-${c.id}',
                            title: c.name,
                            hidden: _isHiddenCat(c),
                            onHidden: (h) => setState(() => _cats[c.id] = h),
                          ),
                    ],
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        16,
                        0,
                      ),
                      child: Text(
                        l10n.hiddenItems,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final i in m.items)
                      if (!breakpoint.isExpanded ||
                          _isHiddenItem(i) == hiddenSide)
                        tile(
                          id: i.id,
                          title: i.name,
                          subtitle: catName[i.categoryId],
                          hidden: _isHiddenItem(i),
                          onHidden: (h) => setState(() => _items[i.id] = h),
                        ),
                  ],
                );

                final header = Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(intro),
                      if (overBy > 0) ...[
                        const SizedBox(height: 8),
                        FormMessage(
                          l10n.hiddenOver(overBy),
                          key: HiddenKeys.over,
                        ),
                      ],
                    ],
                  ),
                );
                final saveButton = Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: AppPrimaryButton(
                    key: HiddenKeys.save,
                    label: widget.downgrade
                        ? l10n.hiddenConfirmDowngrade
                        : l10n.hiddenSave,
                    expand: !breakpoint.isExpanded,
                    loading: _saving,
                    onPressed: overBy > 0 ? null : () => _save(r, m),
                  ),
                );
                final visibleTitle = l10n.hiddenVisible(
                  visibleItems,
                  isUnlimited(maxItems) ? l10n.planUnlimited : '$maxItems',
                );
                final hiddenCount =
                    m.items.length -
                    visibleItems +
                    m.categories.length -
                    visibleCats;
                if (!breakpoint.isExpanded) {
                  // The count and the over-limit message stay in view.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Expanded(
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                visibleTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            section(false),
                            saveButton,
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Card(
                                  key: HiddenKeys.visibleList,
                                  child: ListView(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          visibleTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      section(false),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  key: HiddenKeys.hiddenList,
                                  child: ListView(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          l10n.hiddenHidden(hiddenCount),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      if (hiddenCount == 0)
                                        ListTile(title: Text(l10n.hiddenNone))
                                      else
                                        section(true),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: saveButton,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
