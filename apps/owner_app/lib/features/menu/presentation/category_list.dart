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

enum _CategoryAction { edit, moveUp, moveDown, delete }

/// Categories with their item counts, an active switch, drag handles and a
/// "More" menu whose Move up / Move down are the keyboard alternative to
/// dragging (FR-016 to FR-020).
class CategoryListPane extends ConsumerWidget {
  const CategoryListPane({
    super.key,
    required this.menu,
    required this.onOpen,
    this.selectedId,
  });

  final MenuData menu;

  /// Opens a category ([allItemsId] for every item).
  final ValueChanged<String> onOpen;

  /// Highlighted on wide layouts.
  final String? selectedId;

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    int from,
    int to,
  ) async {
    final seqs = sequencesAfterMove(
      [for (final c in menu.categories) (id: c.id, sequence: c.sequence)],
      from,
      to,
    );
    await runMenuAction(
      context,
      () => ref
          .read(pendingChangesProvider.notifier)
          .reorder(MenuCollection.categories, seqs),
    );
  }

  Future<void> _add(BuildContext context) async {
    final id = await showCategoryEditor(context);
    if (id != null) onOpen(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = menu.categories;
    return Column(
      key: MenuKeys.categoryPane,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.menuCategoriesTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              AppIconButton(
                key: MenuKeys.recentlyDeleted,
                icon: Icons.restore_from_trash_outlined,
                semanticLabel: l10n.menuRecentlyDeleted,
                onPressed: () => context.go(Routes.menuDeleted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: FilledButton.tonalIcon(
            key: MenuKeys.addCategory,
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.menuAddCategory),
          ),
        ),
        Expanded(
          child: categories.isEmpty
              ? EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: l10n.menuNoCategoriesTitle,
                  message: l10n.menuNoCategoriesMessage,
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 88),
                  header: ListTile(
                    key: MenuKeys.allItems,
                    minTileHeight: 56,
                    selected: selectedId == allItemsId,
                    leading: const Icon(Icons.view_list_outlined),
                    title: Text(l10n.menuAllItems),
                    subtitle: Text(l10n.menuItemCount(menu.items.length)),
                    onTap: () => onOpen(allItemsId),
                  ),
                  itemCount: categories.length,
                  onReorder: (from, to) =>
                      _move(context, ref, from, to > from ? to - 1 : to),
                  itemBuilder: (context, i) => _CategoryTile(
                    key: MenuKeys.category(categories[i].id),
                    category: categories[i],
                    index: i,
                    count: categories.length,
                    itemCount: menu.itemsIn(categories[i].id).length,
                    selected: categories[i].id == selectedId,
                    onTap: () => onOpen(categories[i].id),
                    onAction: (action) async {
                      final c = categories[i];
                      switch (action) {
                        case _CategoryAction.edit:
                          await showCategoryEditor(context, category: c);
                        case _CategoryAction.moveUp:
                          await _move(context, ref, i, i - 1);
                        case _CategoryAction.moveDown:
                          await _move(context, ref, i, i + 1);
                        case _CategoryAction.delete:
                          await confirmDeleteCategory(context, ref, c);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    super.key,
    required this.category,
    required this.index,
    required this.count,
    required this.itemCount,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final MenuCategory category;
  final int index;
  final int count;
  final int itemCount;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_CategoryAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final subtitle = [
      l10n.menuItemCount(itemCount),
      if (!category.active) l10n.menuCategoryHidden,
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: ListTile(
        minTileHeight: 64,
        selected: selected,
        selectedTileColor: theme.colorScheme.secondaryContainer,
        contentPadding: const EdgeInsetsDirectional.only(start: 0, end: 0),
        horizontalTitleGap: 4,
        leading: ReorderableDragStartListener(
          index: index,
          child: SizedBox(
            width: 40,
            height: 48,
            child: Icon(
              Icons.drag_indicator,
              semanticLabel: l10n.menuDragToReorder,
            ),
          ),
        ),
        title: Text(
          category.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: category.active
              ? null
              : TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: l10n.menuCategoryActiveLabel(category.name),
              child: Switch(
                key: MenuKeys.categoryActive(category.id),
                value: category.active,
                onChanged: (v) {
                  final rid = ref.read(currentRestaurantIdProvider);
                  if (rid == null) return;
                  runMenuAction(
                    context,
                    () => ref.read(menuRepositoryProvider).updateCategory(
                      rid,
                      category.id,
                      {MenuFields.active: v},
                    ),
                  );
                },
              ),
            ),
            PopupMenuButton<_CategoryAction>(
              key: MenuKeys.categoryMenu(category.id),
              tooltip: l10n.menuMoreFor(category.name),
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _CategoryAction.edit,
                  child: Text(l10n.actionEdit),
                ),
                PopupMenuItem(
                  value: _CategoryAction.moveUp,
                  enabled: index > 0,
                  child: Text(l10n.actionMoveUp),
                ),
                PopupMenuItem(
                  value: _CategoryAction.moveDown,
                  enabled: index < count - 1,
                  child: Text(l10n.actionMoveDown),
                ),
                PopupMenuItem(
                  value: _CategoryAction.delete,
                  child: Text(l10n.actionDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
