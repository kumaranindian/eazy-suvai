import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/menu_state.dart';
import 'category_list.dart';
import 'item_editor.dart';
import 'item_list.dart';
import 'menu_actions.dart';

/// Menu manager (M04).
///
/// * compact: the category list; a category opens its items as a new page,
///   and an item opens the full-screen editor;
/// * medium: categories and items side by side; the editor is a dialog;
/// * expanded: three panes – categories, items, editor.
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(menuDataProvider);
    return data.when(
      skipLoadingOnReload: true,
      loading: () => const LoadingState(),
      error: (e, _) =>
          ErrorState(message: CoreLocalizations.of(context).messageForError(e)),
      data: (menu) => _MenuLayout(menu: menu),
    );
  }
}

class _MenuLayout extends ConsumerWidget {
  const _MenuLayout({required this.menu});

  final MenuData menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoint = Breakpoint.of(context);
    final stored = ref.watch(selectedCategoryProvider);
    final selected = stored == allItemsId
        ? allItemsId
        : (menu.liveCategory(stored)?.id ??
              menu.categories.firstOrNull?.id ??
              allItemsId);

    Future<void> openCategory(String id) async {
      if (breakpoint.isCompact) {
        await context.push(Routes.menuCategory(id));
        return;
      }
      if (!await confirmDiscardEdits(context, ref)) return;
      ref.read(selectedCategoryProvider.notifier).set(id);
      ref.read(bulkSelectionProvider.notifier).set(const {});
      ref.read(editorTargetProvider.notifier).set(null);
    }

    final categories = CategoryListPane(
      menu: menu,
      selectedId: breakpoint.isCompact ? null : selected,
      onOpen: openCategory,
    );
    if (breakpoint.isCompact) return categories;

    final target = ref.watch(editorTargetProvider);
    final items = ItemListPane(
      key: ValueKey('items.$selected'),
      menu: menu,
      categoryId: selected,
      selectedItemId: breakpoint.isExpanded ? target?.itemId : null,
      onOpenItem: (id) => openItemEditor(context, ref, EditorTarget.item(id)),
      onAddItem: () => openItemEditor(
        context,
        ref,
        EditorTarget.create(selected == allItemsId ? null : selected),
      ),
    );

    if (breakpoint.isMedium) {
      return Row(
        children: [
          SizedBox(width: 280, child: categories),
          const VerticalDivider(width: 1),
          Expanded(child: items),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 256, child: categories),
        const VerticalDivider(width: 1),
        Expanded(child: items),
        const VerticalDivider(width: 1),
        const SizedBox(
          key: MenuKeys.editorPane,
          width: 360,
          child: _EditorPane(),
        ),
      ],
    );
  }
}

/// Opens the item editor the way the layout calls for.
Future<void> openItemEditor(
  BuildContext context,
  WidgetRef ref,
  EditorTarget target,
) async {
  final breakpoint = Breakpoint.of(context);
  if (breakpoint.isCompact) {
    await context.push(
      target.isNew
          ? Routes.menuNewItem(target.newInCategory)
          : Routes.menuItem(target.itemId!),
    );
  } else if (breakpoint.isMedium) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ItemEditorDialog(target: target),
    );
  } else {
    if (ref.read(editorTargetProvider) == target) return;
    if (!await confirmDiscardEdits(context, ref)) return;
    ref.read(editorTargetProvider.notifier).set(target);
  }
}

/// The right-hand editor pane of the expanded layout.
class _EditorPane extends ConsumerWidget {
  const _EditorPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final target = ref.watch(editorTargetProvider);
    if (target == null) {
      return EmptyState(
        icon: Icons.edit_note,
        title: l10n.menuEditorEmptyTitle,
        message: l10n.menuEditorEmptyMessage,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorTitle(
          title: target.isNew ? l10n.menuItemNew : l10n.menuItemEdit,
          onClose: () async {
            if (!await confirmDiscardEdits(context, ref)) return;
            ref.read(editorTargetProvider.notifier).set(null);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: ItemEditor(
            key: ValueKey(target),
            target: target,
            onCreated: (id) => ref
                .read(editorTargetProvider.notifier)
                .set(EditorTarget.item(id)),
            onDone: () => ref.read(editorTargetProvider.notifier).set(null),
          ),
        ),
      ],
    );
  }
}

class _EditorTitle extends StatelessWidget {
  const _EditorTitle({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.close,
            semanticLabel: l10n.actionClose,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// The item editor as a 640 px dialog (medium layout).
class ItemEditorDialog extends ConsumerStatefulWidget {
  const ItemEditorDialog({super.key, required this.target});

  final EditorTarget target;

  @override
  ConsumerState<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends ConsumerState<ItemEditorDialog> {
  late EditorTarget _target = widget.target;

  Future<void> _close() async {
    if (!await confirmDiscardEdits(context, ref)) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 640,
        height: (height * 0.9).clamp(320, 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditorTitle(
              title: _target.isNew ? l10n.menuItemNew : l10n.menuItemEdit,
              onClose: _close,
            ),
            const Divider(height: 1),
            Expanded(
              child: ItemEditor(
                key: ValueKey(_target),
                target: _target,
                onCreated: (id) =>
                    setState(() => _target = EditorTarget.item(id)),
                onDone: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen item editor (compact layout), above the navigation bar.
class ItemEditorPage extends ConsumerWidget {
  const ItemEditorPage({super.key, required this.target});

  final EditorTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dirty = ref.watch(editorDirtyProvider);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardEdits(context, ref) && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(target.isNew ? l10n.menuItemNew : l10n.menuItemEdit),
        ),
        body: ItemEditor(
          key: ValueKey(target),
          target: target,
          onCreated: (id) => context.pushReplacement(Routes.menuItem(id)),
          onDone: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.menu);
            }
          },
        ),
      ),
    );
  }
}

/// One category's items as a page (compact layout).
class CategoryItemsPage extends ConsumerWidget {
  const CategoryItemsPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(menuDataProvider);
    final menu = data.value;
    final category = menu?.liveCategory(categoryId);
    final all = categoryId == allItemsId;
    return Scaffold(
      appBar: AppBar(
        title: Text(all ? l10n.menuAllItems : (category?.name ?? '')),
      ),
      body: switch (menu) {
        null => const LoadingState(),
        _ when !all && category == null => EmptyState(
          icon: Icons.search_off,
          title: l10n.menuCategoryGoneTitle,
          message: l10n.menuCategoryGoneMessage,
        ),
        _ => ItemListPane(
          menu: menu,
          categoryId: categoryId,
          showHeader: !all,
          onOpenItem: (id) =>
              openItemEditor(context, ref, EditorTarget.item(id)),
          onAddItem: () => openItemEditor(
            context,
            ref,
            EditorTarget.create(all ? null : categoryId),
          ),
        ),
      },
    );
  }
}
