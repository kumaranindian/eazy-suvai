import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../application/menu_state.dart';
import '../data/menu_repository.dart';
import 'category_dialogs.dart';
import 'menu_actions.dart';

enum _ItemAction { edit, moveUp, moveDown, moveTo, delete }

/// Items of one category (or of every category for [allItemsId]) with
/// search, filters, an availability switch per row and reordering
/// (FR-022 to FR-028, FRD §5.4). On wide layouts rows can be selected for
/// bulk availability, move and delete (FR-097).
class ItemListPane extends ConsumerStatefulWidget {
  const ItemListPane({
    super.key,
    required this.menu,
    required this.categoryId,
    required this.onOpenItem,
    required this.onAddItem,
    this.showHeader = true,
    this.selectedItemId,
  });

  final MenuData menu;
  final String categoryId;
  final ValueChanged<String> onOpenItem;
  final VoidCallback onAddItem;

  /// False when the page's app bar already names the category.
  final bool showHeader;

  /// Highlighted on the expanded layout (open in the editor pane).
  final String? selectedItemId;

  @override
  ConsumerState<ItemListPane> createState() => _ItemListPaneState();
}

class _ItemListPaneState extends ConsumerState<ItemListPane> {
  late final _search = TextEditingController(
    text: ref.read(itemFilterProvider).query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _all => widget.categoryId == allItemsId;

  List<MenuItem> get _source =>
      _all ? widget.menu.items : widget.menu.itemsIn(widget.categoryId);

  Future<void> _move(int from, int to) async {
    final items = _source;
    final seqs = sequencesAfterMove(
      [for (final i in items) (id: i.id, sequence: i.sequence)],
      from,
      to,
    );
    await runMenuAction(
      context,
      () => ref
          .read(pendingChangesProvider.notifier)
          .reorder(MenuCollection.items, seqs),
    );
  }

  /// Availability goes live without a publish (FR-095, BR-018), so the
  /// publish bar does not appear. Say so, once the menu is live at all.
  Future<void> _setAvailable(Iterable<String> ids, bool value) {
    final list = ids.toList();
    final published =
        ref.read(currentRestaurantProvider).value?.publishedVersion != null;
    return runMenuAction(
      context,
      () => ref
          .read(pendingChangesProvider.notifier)
          .setAvailability(list, value),
      success: published
          ? AppLocalizations.of(
              context,
            ).menuAvailabilityLive(list.length, value.toString())
          : null,
    );
  }

  Future<void> _moveTo(List<String> ids, {String? exclude}) async {
    final l10n = AppLocalizations.of(context);
    final rid = ref.read(currentRestaurantIdProvider);
    final target = await pickCategory(
      context,
      categories: widget.menu.categories,
      title: l10n.menuMoveItemsTitle(ids.length),
      exclude: exclude,
    );
    if (target == null || rid == null || !mounted) return;
    final name = widget.menu.category(target)?.name ?? '';
    final ok = await runMenuAction(
      context,
      () => ref.read(menuRepositoryProvider).moveItems(rid, ids, target),
      success: l10n.menuItemsMoved(ids.length, name),
    );
    if (ok) ref.read(bulkSelectionProvider.notifier).set(const {});
  }

  Future<void> _delete(List<String> ids, String label) async {
    final l10n = AppLocalizations.of(context);
    final rid = ref.read(currentRestaurantIdProvider);
    if (rid == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.menuDeleteItemsTitle(ids.length),
      message: l10n.menuDeleteItemsMessage,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final ok = await runMenuAction(
      context,
      () => repo.deleteItems(rid, ids),
      success: l10n.menuDeletedToBin(label),
      onUndo: ids.length == 1
          ? () => repo.restore(rid, category: false, id: ids.single)
          : null,
    );
    if (ok) {
      ref.read(bulkSelectionProvider.notifier).set(const {});
      final target = ref.read(editorTargetProvider);
      if (target?.itemId != null && ids.contains(target!.itemId)) {
        ref.read(editorTargetProvider.notifier).set(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wide = !Breakpoint.of(context).isCompact;
    final filter = ref.watch(itemFilterProvider);
    final selection = ref.watch(bulkSelectionProvider);
    final labels = ref.watch(dietaryLabelsProvider).value ?? const [];
    final tags = ref.watch(itemTagsProvider).value ?? const [];
    final restaurant = ref.watch(currentRestaurantProvider).value;
    final currency =
        restaurant != null && Currencies.isKnown(restaurant.currency)
        ? Currencies.of(restaurant.currency)
        : null;

    final source = _source;
    final items = [
      for (final i in source)
        if (filter.matches(i)) i,
    ];
    final soldOut = source.where((i) => !i.available).length;
    // Chips only for labels and tags in use here (or already chosen).
    final usedLabelIds = {
      for (final i in source) i.dietaryLabelId,
      ...filter.labelIds,
    };
    final usedTagIds = {for (final i in source) ...i.tagIds, ...filter.tagIds};
    final usedLabels = [
      for (final l in selectableLabels(labels, keep: filter.labelIds))
        if (usedLabelIds.contains(l.id)) l,
    ];
    final usedTags = [
      for (final t in selectableLabels(tags, keep: filter.tagIds))
        if (usedTagIds.contains(t.id)) t,
    ];
    final reorderable = !_all && !filter.isActive;
    final category = widget.menu.liveCategory(widget.categoryId);
    final visibleSelection = {
      for (final i in items)
        if (selection.contains(i.id)) i.id,
    };

    Widget row(int index, MenuItem item) => _ItemRow(
      key: MenuKeys.item(item.id),
      item: item,
      index: index,
      count: items.length,
      currency: currency,
      label: _labelFor(labels, item.dietaryLabelId),
      tags: [
        for (final id in item.tagIds)
          if (_labelFor(tags, id) case final t?) t,
      ],
      categoryName: _all ? widget.menu.category(item.categoryId)?.name : null,
      reorderable: reorderable,
      selectable: wide,
      selected: selection.contains(item.id),
      highlighted: item.id == widget.selectedItemId,
      onTap: () => widget.onOpenItem(item.id),
      onAvailable: (v) => _setAvailable([item.id], v),
      onSelect: (v) {
        final next = {...selection};
        v ? next.add(item.id) : next.remove(item.id);
        ref.read(bulkSelectionProvider.notifier).set(next);
      },
      onAction: (action) async {
        switch (action) {
          case _ItemAction.edit:
            widget.onOpenItem(item.id);
          case _ItemAction.moveUp:
            await _move(index, index - 1);
          case _ItemAction.moveDown:
            await _move(index, index + 1);
          case _ItemAction.moveTo:
            await _moveTo([item.id], exclude: item.categoryId);
          case _ItemAction.delete:
            await _delete([item.id], item.name);
        }
      },
    );

    return Column(
      key: MenuKeys.itemPane,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _all ? l10n.menuAllItems : (category?.name ?? ''),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (category != null) ...[
                  AppIconButton(
                    icon: Icons.edit_outlined,
                    semanticLabel: l10n.menuCategoryEdit,
                    onPressed: () =>
                        showCategoryEditor(context, category: category),
                  ),
                  AppIconButton(
                    icon: Icons.delete_outline,
                    semanticLabel: l10n.menuDeleteCategoryTitle(category.name),
                    onPressed: () =>
                        confirmDeleteCategory(context, ref, category),
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: MenuKeys.search,
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.menuSearchHint,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.menuSearchClear,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              ref
                                  .read(itemFilterProvider.notifier)
                                  .set(filter.copyWith(query: ''));
                            },
                          ),
                  ),
                  onChanged: (v) => ref
                      .read(itemFilterProvider.notifier)
                      .set(filter.copyWith(query: v)),
                ),
              ),
              if (category != null) ...[
                const SizedBox(width: 8),
                if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
                  IconButton.filled(
                    key: MenuKeys.addItem,
                    tooltip: l10n.menuAddItem,
                    onPressed: widget.onAddItem,
                    icon: const Icon(Icons.add),
                  )
                else
                  FilledButton.icon(
                    key: MenuKeys.addItem,
                    onPressed: widget.onAddItem,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.menuAddItem),
                  ),
              ],
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
          child: Row(
            children: [
              FilterChip(
                key: MenuKeys.filterSoldOut,
                label: Text(l10n.menuFilterSoldOut(soldOut)),
                selected: filter.soldOut,
                onSelected: (v) => ref
                    .read(itemFilterProvider.notifier)
                    .set(filter.copyWith(soldOut: v)),
              ),
              const SizedBox(width: 8),
              FilterChip(
                key: MenuKeys.filterFeatured,
                label: Text(l10n.menuFilterFeatured),
                selected: filter.featured,
                onSelected: (v) => ref
                    .read(itemFilterProvider.notifier)
                    .set(filter.copyWith(featured: v)),
              ),
              for (final label in usedLabels) ...[
                const SizedBox(width: 8),
                FilterChip(
                  key: ValueKey('menu.filter.label.${label.id}'),
                  avatar: MenuLabelIcon(label: label, size: 16),
                  label: Text(label.name),
                  selected: filter.labelIds.contains(label.id),
                  onSelected: (v) => ref
                      .read(itemFilterProvider.notifier)
                      .set(filter.toggleLabel(label.id, v)),
                ),
              ],
              if (usedTags.isNotEmpty) ...[
                const SizedBox(width: 8),
                const SizedBox(height: 32, child: VerticalDivider(width: 8)),
              ],
              for (final tag in usedTags) ...[
                const SizedBox(width: 8),
                FilterChip(
                  key: ValueKey('menu.filter.tag.${tag.id}'),
                  avatar: tag.icon.isEmpty
                      ? null
                      : MenuLabelIcon(label: tag, size: 16),
                  label: Text(tag.name),
                  selected: filter.tagIds.contains(tag.id),
                  onSelected: (v) => ref
                      .read(itemFilterProvider.notifier)
                      .set(filter.toggleTag(tag.id, v)),
                ),
              ],
            ],
          ),
        ),
        if (wide && selection.isNotEmpty)
          _BulkBar(
            selected: visibleSelection.length,
            allSelected:
                items.isNotEmpty && visibleSelection.length == items.length,
            onSelectAll: (v) => ref
                .read(bulkSelectionProvider.notifier)
                .set(v ? {for (final i in items) i.id} : const {}),
            onAvailable: (v) => _setAvailable(visibleSelection, v),
            onMove: () => _moveTo(visibleSelection.toList()),
            onDelete: () => _delete(
              visibleSelection.toList(),
              l10n.menuItemCount(visibleSelection.length),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: filter.isActive
                      ? Icons.search_off
                      : Icons.restaurant_outlined,
                  title: filter.isActive
                      ? l10n.menuNoMatchTitle
                      : l10n.menuNoItemsTitle,
                  message: filter.isActive
                      ? l10n.menuNoMatchMessage
                      : (category == null
                            ? l10n.menuNoItemsAll
                            : l10n.menuNoItemsMessage),
                  actionLabel: category != null && !filter.isActive
                      ? l10n.menuAddItem
                      : null,
                  onAction: category != null && !filter.isActive
                      ? widget.onAddItem
                      : null,
                )
              : reorderable
              ? ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  onReorder: (from, to) => _move(from, to > from ? to - 1 : to),
                  itemBuilder: (context, i) => row(i, items[i]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  itemBuilder: (context, i) => row(i, items[i]),
                ),
        ),
      ],
    );
  }
}

MenuLabel? _labelFor(List<MenuLabel> labels, String id) {
  for (final l in labels) {
    if (l.id == id) return l;
  }
  return null;
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.count,
    required this.currency,
    required this.label,
    required this.tags,
    required this.categoryName,
    required this.reorderable,
    required this.selectable,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    required this.onAvailable,
    required this.onSelect,
    required this.onAction,
  });

  final MenuItem item;
  final int index;
  final int count;
  final Currency? currency;
  final MenuLabel? label;
  final List<MenuLabel> tags;
  final String? categoryName;
  final bool reorderable;
  final bool selectable;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onAvailable;
  final ValueChanged<bool> onSelect;
  final ValueChanged<_ItemAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final price = currency == null
        ? '${item.priceMinor}'
        : Money.of(item.priceMinor, currency!).format();
    return Material(
      color: highlighted ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 0, 8),
            child: Row(
              children: [
                if (selectable)
                  Checkbox(
                    key: MenuKeys.itemSelect(item.id),
                    value: selected,
                    semanticLabel: l10n.menuSelectItem(item.name),
                    onChanged: (v) => onSelect(v ?? false),
                  )
                else
                  const SizedBox(width: 8),
                // The thumbnail gives way to the name at large text sizes (M13).
                if (MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                  SizedBox.square(
                    dimension: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Opacity(
                        opacity: item.available ? 1 : 0.5,
                        child: item.image == null
                            ? ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.fastfood_outlined),
                              )
                            : ResponsiveImage(image: item.image!),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.featured) ...[
                            Icon(
                              Icons.star,
                              size: 16,
                              color: BrandColors.orangeText,
                              semanticLabel: l10n.menuFieldFeatured,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                decoration: item.available
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(price, style: theme.textTheme.bodyMedium),
                          if (label != null) MenuLabelBadge(label: label!),
                          if (!item.available)
                            Text(
                              l10n.menuSoldOut,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (categoryName != null)
                            Text(categoryName!, style: muted),
                          for (final t in tags)
                            MenuLabelBadge(label: t, iconSize: 14),
                        ],
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: l10n.menuAvailableLabel(item.name),
                  child: Switch(
                    key: MenuKeys.itemAvailable(item.id),
                    value: item.available,
                    onChanged: onAvailable,
                  ),
                ),
                PopupMenuButton<_ItemAction>(
                  key: MenuKeys.itemMenu(item.id),
                  tooltip: l10n.menuMoreFor(item.name),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _ItemAction.edit,
                      child: Text(l10n.actionEdit),
                    ),
                    if (reorderable) ...[
                      PopupMenuItem(
                        value: _ItemAction.moveUp,
                        enabled: index > 0,
                        child: Text(l10n.actionMoveUp),
                      ),
                      PopupMenuItem(
                        value: _ItemAction.moveDown,
                        enabled: index < count - 1,
                        child: Text(l10n.actionMoveDown),
                      ),
                    ],
                    PopupMenuItem(
                      value: _ItemAction.moveTo,
                      child: Text(l10n.menuMoveToCategory),
                    ),
                    PopupMenuItem(
                      value: _ItemAction.delete,
                      child: Text(l10n.actionDelete),
                    ),
                  ],
                ),
                if (reorderable)
                  ReorderableDragStartListener(
                    index: index,
                    child: SizedBox(
                      width: 40,
                      height: 48,
                      child: Icon(
                        Icons.drag_indicator,
                        semanticLabel: l10n.menuDragToReorder,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.selected,
    required this.allSelected,
    required this.onSelectAll,
    required this.onAvailable,
    required this.onMove,
    required this.onDelete,
  });

  final int selected;
  final bool allSelected;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<bool> onAvailable;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: MenuKeys.bulkBar,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Checkbox(
              key: MenuKeys.bulkSelectAll,
              value: allSelected,
              semanticLabel: l10n.menuSelectAll,
              onChanged: (v) => onSelectAll(v ?? false),
            ),
            Semantics(
              liveRegion: true,
              child: Text(l10n.menuSelectedCount(selected)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: MenuKeys.bulkAvailable,
              onPressed: selected == 0 ? null : () => onAvailable(true),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l10n.menuBulkAvailable),
            ),
            TextButton.icon(
              key: MenuKeys.bulkSoldOut,
              onPressed: selected == 0 ? null : () => onAvailable(false),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(l10n.menuBulkSoldOut),
            ),
            TextButton.icon(
              key: MenuKeys.bulkMove,
              onPressed: selected == 0 ? null : onMove,
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(l10n.menuMoveToCategory),
            ),
            TextButton.icon(
              key: MenuKeys.bulkDelete,
              onPressed: selected == 0 ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.actionDelete),
            ),
          ],
        ),
      ),
    );
  }
}
