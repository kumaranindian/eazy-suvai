import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../application/menu_state.dart';
import '../data/menu_repository.dart';
import 'menu_actions.dart';

/// Keys used by tests.
abstract final class CategoryDialogKeys {
  static const name = ValueKey('category.name');
  static const description = ValueKey('category.description');
  static const active = ValueKey('category.active');
  static const save = ValueKey('category.save');
  static const modeMove = ValueKey('category.delete.move');
  static const modeDeleteAll = ValueKey('category.delete.all');
  static const target = ValueKey('category.delete.target');
  static const confirmName = ValueKey('category.delete.confirmName');
  static const confirm = ValueKey('category.delete.confirm');
}

/// Creates a category, or edits [category] (FR-015 to FR-017). Returns the
/// id of a new category.
Future<String?> showCategoryEditor(
  BuildContext context, {
  MenuCategory? category,
}) => showDialog<String>(
  context: context,
  builder: (_) => _CategoryEditorDialog(category: category),
);

class _CategoryEditorDialog extends ConsumerStatefulWidget {
  const _CategoryEditorDialog({this.category});

  final MenuCategory? category;

  @override
  ConsumerState<_CategoryEditorDialog> createState() =>
      _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends ConsumerState<_CategoryEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late bool _active = widget.category?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final rid = ref.read(currentRestaurantIdProvider);
    if (rid == null) return;
    final repo = ref.read(menuRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final existing = widget.category;
    final name = _name.text.trim();
    final description = _description.text.trim();
    setState(() => _saving = true);
    String? id;
    final ok = await runMenuAction(context, () async {
      if (existing == null) {
        id = await repo.createCategory(
          rid,
          name: name,
          description: description,
          active: _active,
        );
      } else {
        final fields = <String, Object?>{
          if (name != existing.name) MenuFields.name: name,
          if (description != existing.description)
            MenuFields.description: description,
          if (_active != existing.active) MenuFields.active: _active,
        };
        if (fields.isNotEmpty) {
          await repo.updateCategory(rid, existing.id, fields);
        }
        id = existing.id;
      }
    }, success: existing == null ? l10n.menuCategoryAdded(name) : null);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final category = widget.category;
    final rid = ref.watch(currentRestaurantIdProvider);
    // The picker writes the image itself; follow the live document.
    final live = category == null
        ? null
        : ref.watch(menuDataProvider).value?.category(category.id);
    return AlertDialog(
      title: Text(
        category == null ? l10n.menuCategoryNew : l10n.menuCategoryEdit,
      ),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: CategoryDialogKeys.name,
                controller: _name,
                autofocus: category == null,
                maxLength: MenuLimits.categoryName,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.menuFieldCategoryName,
                  hintText: l10n.menuFieldCategoryNameHint,
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.menuErrorNameRequired
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: CategoryDialogKeys.description,
                controller: _description,
                maxLength: MenuLimits.categoryDescription,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.menuFieldDescriptionOptional,
                ),
              ),
              SwitchListTile(
                key: CategoryDialogKeys.active,
                contentPadding: EdgeInsetsDirectional.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l10n.menuFieldCategoryActive),
                subtitle: Text(l10n.menuFieldCategoryActiveHelp),
              ),
              const SizedBox(height: 8),
              if (category != null && rid != null)
                ImagePickerField(
                  purpose: ImagePurpose.category,
                  restaurantId: rid,
                  targetPath: 'restaurants/$rid/categories/${category.id}',
                  label: l10n.menuFieldPhoto,
                  value: live?.image,
                  onRemove: () =>
                      ref.read(menuRepositoryProvider).updateCategory(
                        rid,
                        category.id,
                        {MenuFields.image: null},
                      ),
                )
              else
                Text(
                  l10n.menuPhotoAfterSave,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(core.actionCancel),
        ),
        AppPrimaryButton(
          key: CategoryDialogKeys.save,
          label: category == null ? l10n.actionAdd : l10n.actionSave,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// Deletes [category] (FR-018, AC-027). Empty: one confirmation. With items:
/// move them to another category, or delete them too after typing the
/// category name. A bottom sheet on phones, a dialog otherwise. Returns
/// whether the category was deleted.
Future<bool> confirmDeleteCategory(
  BuildContext context,
  WidgetRef ref,
  MenuCategory category,
) async {
  final l10n = AppLocalizations.of(context);
  final menu = ref.read(menuDataProvider).value;
  final rid = ref.read(currentRestaurantIdProvider);
  if (menu == null || rid == null) return false;
  final repo = ref.read(menuRepositoryProvider);
  final count = menu.itemsIn(category.id).length;
  Future<void> undo() => repo.restore(rid, category: true, id: category.id);

  if (count == 0) {
    final ok = await showConfirmDialog(
      context,
      title: l10n.menuDeleteCategoryTitle(category.name),
      message: l10n.menuDeleteCategoryEmpty,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return runMenuAction(
      context,
      () => repo.deleteCategory(
        rid,
        category.id,
        mode: DeleteCategoryMode.deleteAll,
      ),
      success: l10n.menuDeletedToBin(category.name),
      onUndo: undo,
    );
  }

  final others = [
    for (final c in menu.categories)
      if (c.id != category.id) c,
  ];
  final body = _DeleteCategoryForm(
    category: category,
    itemCount: count,
    others: others,
  );
  final Future<_DeleteChoice?> asked;
  if (Breakpoint.of(context).isCompact) {
    asked = showModalBottomSheet<_DeleteChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => body,
    );
  } else {
    asked = showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: body,
        ),
      ),
    );
  }
  final choice = await asked;
  if (choice == null || !context.mounted) return false;
  return runMenuAction(
    context,
    () => repo.deleteCategory(
      rid,
      category.id,
      mode: choice.mode,
      targetCategoryId: choice.targetId,
      confirmName: choice.confirmName,
    ),
    success: choice.mode == DeleteCategoryMode.move
        ? l10n.menuCategoryDeletedMoved(category.name, count)
        : l10n.menuDeletedToBin(category.name),
    onUndo: choice.mode == DeleteCategoryMode.deleteAll ? undo : null,
  );
}

class _DeleteChoice {
  const _DeleteChoice(this.mode, {this.targetId, this.confirmName});

  final DeleteCategoryMode mode;
  final String? targetId;
  final String? confirmName;
}

class _DeleteCategoryForm extends StatefulWidget {
  const _DeleteCategoryForm({
    required this.category,
    required this.itemCount,
    required this.others,
  });

  final MenuCategory category;
  final int itemCount;
  final List<MenuCategory> others;

  @override
  State<_DeleteCategoryForm> createState() => _DeleteCategoryFormState();
}

class _DeleteCategoryFormState extends State<_DeleteCategoryForm> {
  late DeleteCategoryMode _mode = widget.others.isEmpty
      ? DeleteCategoryMode.deleteAll
      : DeleteCategoryMode.move;
  late String? _target = widget.others.firstOrNull?.id;
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  String _norm(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool get _canConfirm => switch (_mode) {
    DeleteCategoryMode.move => _target != null,
    DeleteCategoryMode.deleteAll =>
      _norm(_typed.text) == _norm(widget.category.name),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final insets = MediaQuery.viewInsetsOf(context);
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.menuDeleteCategoryTitle(widget.category.name),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.menuDeleteCategoryHasItems(widget.itemCount)),
          const SizedBox(height: 16),
          _RadioGroup(
            children: [
              RadioListTile<DeleteCategoryMode>(
                key: CategoryDialogKeys.modeMove,
                contentPadding: EdgeInsetsDirectional.zero,
                value: DeleteCategoryMode.move,
                groupValue: _mode,
                onChanged: widget.others.isEmpty
                    ? null
                    : (v) => setState(() => _mode = v!),
                title: Text(l10n.menuDeleteModeMove(widget.itemCount)),
                subtitle: widget.others.isEmpty
                    ? Text(l10n.menuDeleteModeMoveNone)
                    : null,
              ),
              if (_mode == DeleteCategoryMode.move && widget.others.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 16,
                    bottom: 8,
                  ),
                  child: DropdownButtonFormField<String>(
                    key: CategoryDialogKeys.target,
                    value: _target,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.menuDeleteMoveTo,
                    ),
                    items: [
                      for (final c in widget.others)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _target = v),
                  ),
                ),
              RadioListTile<DeleteCategoryMode>(
                key: CategoryDialogKeys.modeDeleteAll,
                contentPadding: EdgeInsetsDirectional.zero,
                value: DeleteCategoryMode.deleteAll,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: Text(l10n.menuDeleteModeAll(widget.itemCount)),
              ),
            ],
          ),
          if (_mode == DeleteCategoryMode.deleteAll) ...[
            const SizedBox(height: 8),
            Text(l10n.menuDeleteTypeName(widget.category.name)),
            const SizedBox(height: 8),
            TextField(
              key: CategoryDialogKeys.confirmName,
              controller: _typed,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.menuFieldCategoryName,
                hintText: widget.category.name,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.menuDeleteRestoreNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(core.actionCancel),
              ),
              FilledButton(
                key: CategoryDialogKeys.confirm,
                style: _mode == DeleteCategoryMode.deleteAll
                    ? FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      )
                    : null,
                onPressed: _canConfirm
                    ? () => Navigator.of(context).pop(
                        _DeleteChoice(
                          _mode,
                          targetId: _mode == DeleteCategoryMode.move
                              ? _target
                              : null,
                          confirmName: _mode == DeleteCategoryMode.deleteAll
                              ? _typed.text
                              : null,
                        ),
                      )
                    : null,
                child: Text(
                  _mode == DeleteCategoryMode.move
                      ? l10n.menuDeleteMoveConfirm
                      : l10n.menuDeleteAllConfirm(widget.itemCount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Groups radio tiles for assistive technology.
class _RadioGroup extends StatelessWidget {
  const _RadioGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Asks which category to move items into (FR-097). Returns its id.
Future<String?> pickCategory(
  BuildContext context, {
  required List<MenuCategory> categories,
  required String title,
  String? exclude,
}) {
  final options = [
    for (final c in categories)
      if (c.id != exclude) c,
  ];
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: [
        for (final c in options)
          SimpleDialogOption(
            key: ValueKey('pickCategory.${c.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(c.id),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              child: Text(c.name),
            ),
          ),
      ],
    ),
  );
}
