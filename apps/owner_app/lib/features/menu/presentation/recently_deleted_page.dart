import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../application/menu_state.dart';
import '../data/menu_repository.dart';
import 'category_dialogs.dart';
import 'menu_actions.dart';

/// Soft-deleted categories and items, restorable for 30 days (FR-098,
/// AC-028). Restored content returns to the draft, not the live menu.
class RecentlyDeletedPage extends ConsumerWidget {
  const RecentlyDeletedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(menuDataProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.menu),
        ),
        title: Text(l10n.menuRecentlyDeleted),
      ),
      body: data.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: CoreLocalizations.of(context).messageForError(e),
        ),
        data: (menu) => _DeletedList(menu: menu),
      ),
    );
  }
}

class _DeletedList extends ConsumerWidget {
  const _DeletedList({required this.menu});

  final MenuData menu;

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref, {
    required bool category,
    required String id,
    required String name,
    String? needsCategoryFrom,
  }) async {
    final l10n = AppLocalizations.of(context);
    final rid = ref.read(currentRestaurantIdProvider);
    if (rid == null) return;
    String? target;
    if (needsCategoryFrom != null) {
      if (menu.categories.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.menuRestoreNeedsCategory)));
        return;
      }
      target = await pickCategory(
        context,
        categories: menu.categories,
        title: l10n.menuRestoreInto(name),
      );
      if (target == null || !context.mounted) return;
    }
    await runMenuAction(
      context,
      () => ref
          .read(menuRepositoryProvider)
          .restore(rid, category: category, id: id, targetCategoryId: target),
      success: l10n.menuRestored(name),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    bool restorable(DateTime? until) => until != null && until.isAfter(now);
    final categories = [
      for (final c in menu.deletedCategories)
        if (restorable(c.restoreUntil)) c,
    ];
    final items = [
      for (final i in menu.deletedItemsAlone)
        if (restorable(i.restoreUntil)) i,
    ];
    if (categories.isEmpty && items.isEmpty) {
      return EmptyState(
        icon: Icons.delete_outline,
        title: l10n.menuDeletedEmptyTitle,
        message: l10n.menuDeletedEmptyMessage,
      );
    }

    Widget restoreButton(String id, VoidCallback onPressed, String name) =>
        Semantics(
          label: l10n.menuRestoreLabel(name),
          excludeSemantics: true,
          button: true,
          child: OutlinedButton(
            key: MenuKeys.restore(id),
            onPressed: onPressed,
            child: Text(l10n.actionRestore),
          ),
        );

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall),
      ),
    );

    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsetsDirectional.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
              child: Text(
                l10n.menuDeletedIntro,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (categories.isNotEmpty) heading(l10n.menuCategoriesTitle),
            for (final c in categories)
              ListTile(
                minTileHeight: 64,
                leading: const Icon(Icons.folder_delete_outlined),
                title: Text(c.name),
                subtitle: Text(
                  [
                    if (menu.deletedWith(c.id).isNotEmpty)
                      l10n.menuDeletedWithItems(menu.deletedWith(c.id).length),
                    daysLeftLabel(l10n, c.restoreUntil),
                  ].join(' · '),
                ),
                trailing: restoreButton(
                  c.id,
                  () => _restore(
                    context,
                    ref,
                    category: true,
                    id: c.id,
                    name: c.name,
                  ),
                  c.name,
                ),
              ),
            if (items.isNotEmpty) heading(l10n.menuItemsTitle),
            for (final i in items)
              Builder(
                builder: (context) {
                  final category = menu.category(i.categoryId);
                  final orphan = category == null || category.isDeleted;
                  return ListTile(
                    minTileHeight: 64,
                    leading: const Icon(Icons.fastfood_outlined),
                    title: Text(i.name),
                    subtitle: Text(
                      [
                        if (category != null)
                          orphan
                              ? l10n.menuDeletedCategoryGone(category.name)
                              : category.name,
                        daysLeftLabel(l10n, i.restoreUntil),
                      ].join(' · '),
                    ),
                    trailing: restoreButton(
                      i.id,
                      () => _restore(
                        context,
                        ref,
                        category: false,
                        id: i.id,
                        name: i.name,
                        needsCategoryFrom: orphan ? i.categoryId : null,
                      ),
                      i.name,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
