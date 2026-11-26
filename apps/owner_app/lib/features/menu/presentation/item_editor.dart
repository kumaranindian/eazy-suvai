import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../application/menu_state.dart';
import '../data/menu_repository.dart';
import 'menu_actions.dart';

/// Keys used by tests.
abstract final class ItemEditorKeys {
  static const name = ValueKey('item.name');
  static const category = ValueKey('item.category');
  static const price = ValueKey('item.price');
  static const description = ValueKey('item.description');
  static const available = ValueKey('item.available');
  static const featured = ValueKey('item.featured');
  static const save = ValueKey('item.save');
  static const delete = ValueKey('item.delete');
  static const close = ValueKey('item.close');
  static const dietaryError = ValueKey('item.dietary.error');

  static ValueKey<String> dietary(String id) => ValueKey('item.dietary.$id');
  static ValueKey<String> tag(String id) => ValueKey('item.tag.$id');
}

/// Values of the item form.
@immutable
class _ItemForm {
  const _ItemForm({
    required this.name,
    required this.description,
    required this.categoryId,
    required this.priceMinor,
    required this.dietaryLabelId,
    required this.tagIds,
    required this.available,
    required this.featured,
  });

  factory _ItemForm.of(MenuItem item) => _ItemForm(
    name: item.name,
    description: item.description,
    categoryId: item.categoryId,
    priceMinor: item.priceMinor,
    dietaryLabelId: item.dietaryLabelId,
    tagIds: item.tagIds.toSet(),
    available: item.available,
    featured: item.featured,
  );

  final String name;
  final String description;
  final String? categoryId;
  final int? priceMinor;
  final String? dietaryLabelId;
  final Set<String> tagIds;
  final bool available;
  final bool featured;

  @override
  bool operator ==(Object other) =>
      other is _ItemForm &&
      other.name.trim() == name.trim() &&
      other.description.trim() == description.trim() &&
      other.categoryId == categoryId &&
      other.priceMinor == priceMinor &&
      other.dietaryLabelId == dietaryLabelId &&
      setEquals(other.tagIds, tagIds) &&
      other.available == available &&
      other.featured == featured;

  @override
  int get hashCode => Object.hash(name, categoryId, priceMinor);
}

/// Creates or edits an item (FR-022 to FR-033).
///
/// Shown as a full-screen page on phones, a 640 px dialog on tablets and the
/// right-hand pane on desktops; Save is pinned to the bottom. A photo can be
/// added once the item exists (the upload needs its document, M02), so
/// after creating, the editor switches to the new item via [onCreated].
class ItemEditor extends ConsumerStatefulWidget {
  const ItemEditor({
    super.key,
    required this.target,
    required this.onCreated,
    required this.onDone,
  });

  final EditorTarget target;

  /// The new item's id after a create.
  final ValueChanged<String> onCreated;

  /// After saving an existing item, deleting, or cancelling.
  final VoidCallback onDone;

  @override
  ConsumerState<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<ItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late _ItemForm _initial;
  String? _categoryId;
  int? _priceMinor;
  String? _dietaryId;
  late Set<String> _tags;
  bool _available = true;
  bool _featured = false;
  bool _saving = false;
  bool _missingItem = false;

  @override
  void initState() {
    super.initState();
    final menu = ref.read(menuDataProvider).value;
    final id = widget.target.itemId;
    final item = id == null ? null : menu?.item(id);
    if (id != null && item == null) _missingItem = true;
    final firstCategory = menu?.categories.firstOrNull?.id;
    _initial = item != null
        ? _ItemForm.of(item)
        : _ItemForm(
            name: '',
            description: '',
            categoryId:
                menu?.liveCategory(widget.target.newInCategory)?.id ??
                firstCategory,
            priceMinor: null,
            dietaryLabelId: null,
            tagIds: const {},
            available: true,
            featured: false,
          );
    _name = TextEditingController(text: _initial.name)..addListener(_changed);
    _description = TextEditingController(text: _initial.description)
      ..addListener(_changed);
    _categoryId = _initial.categoryId;
    _priceMinor = _initial.priceMinor;
    _dietaryId = _initial.dietaryLabelId;
    _tags = {..._initial.tagIds};
    _available = _initial.available;
    _featured = _initial.featured;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  _ItemForm get _current => _ItemForm(
    name: _name.text,
    description: _description.text,
    categoryId: _categoryId,
    priceMinor: _priceMinor,
    dietaryLabelId: _dietaryId,
    tagIds: _tags,
    available: _available,
    featured: _featured,
  );

  bool get _dirty => _current != _initial;

  void _changed() {
    final dirty = _dirty;
    Future.microtask(() {
      if (!mounted) return;
      if (ref.read(editorDirtyProvider) != dirty) {
        ref.read(editorDirtyProvider.notifier).set(dirty);
      }
    });
    setState(() {});
  }

  void _update(VoidCallback fn) {
    fn();
    _changed();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rid = ref.read(currentRestaurantIdProvider);
    if (rid == null) return;
    final repo = ref.read(menuRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final form = _current;
    final name = form.name.trim();
    final description = form.description.trim();
    setState(() => _saving = true);
    final id = widget.target.itemId;
    String? created;
    final ok = await runMenuAction(context, () async {
      if (id == null) {
        created = await repo.createItem(
          rid,
          NewItem(
            categoryId: form.categoryId!,
            name: name,
            description: description,
            priceMinor: form.priceMinor!,
            dietaryLabelId: form.dietaryLabelId!,
            tagIds: form.tagIds.toList(),
            available: form.available,
            featured: form.featured,
          ),
        );
        return;
      }
      final before = _initial;
      final fields = <String, Object?>{
        if (name != before.name.trim()) MenuFields.name: name,
        if (description != before.description.trim())
          MenuFields.description: description,
        if (form.priceMinor != before.priceMinor)
          MenuFields.priceMinor: form.priceMinor,
        if (form.dietaryLabelId != before.dietaryLabelId)
          MenuFields.dietaryLabelId: form.dietaryLabelId,
        if (!setEquals(form.tagIds, before.tagIds))
          MenuFields.tagIds: form.tagIds.toList(),
        if (form.available != before.available)
          MenuFields.available: form.available,
        if (form.featured != before.featured)
          MenuFields.featured: form.featured,
      };
      if (fields.isNotEmpty) await repo.updateItem(rid, id, fields);
      if (form.categoryId != before.categoryId) {
        await repo.moveItems(rid, [id], form.categoryId!);
      }
    }, success: id == null ? l10n.menuItemAdded(name) : l10n.menuItemSaved);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    _initial = form;
    ref.read(editorDirtyProvider.notifier).set(false);
    if (created != null) {
      widget.onCreated(created!);
    } else {
      widget.onDone();
    }
  }

  Future<void> _delete(MenuItem item) async {
    final l10n = AppLocalizations.of(context);
    final rid = ref.read(currentRestaurantIdProvider);
    if (rid == null) return;
    final ok = await showConfirmDialog(
      context,
      title: l10n.menuDeleteItemsTitle(1),
      message: l10n.menuDeleteItemsMessage,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final done = await runMenuAction(
      context,
      () => repo.deleteItems(rid, [item.id]),
      success: l10n.menuDeletedToBin(item.name),
      onUndo: () => repo.restore(rid, category: false, id: item.id),
    );
    if (done && mounted) {
      ref.read(editorDirtyProvider.notifier).set(false);
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final menu = ref.watch(menuDataProvider).value;
    final restaurant = ref.watch(currentRestaurantProvider).value;
    final rid = ref.watch(currentRestaurantIdProvider);
    final labels = ref.watch(dietaryLabelsProvider).value ?? const [];
    final tags = ref.watch(itemTagsProvider).value ?? const [];
    final id = widget.target.itemId;
    final item = id == null ? null : menu?.item(id);

    if (menu == null || restaurant == null) return const LoadingState();
    if (_missingItem || (id != null && item == null)) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.menuItemGoneTitle,
        message: l10n.menuItemGoneMessage,
        actionLabel: l10n.actionClose,
        onAction: widget.onDone,
      );
    }
    if (menu.categories.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: l10n.menuNoCategoriesTitle,
        message: l10n.menuItemNeedsCategory,
      );
    }
    final currency = Currencies.isKnown(restaurant.currency)
        ? Currencies.of(restaurant.currency)
        : Currencies.inr;
    final dietary = selectableLabels(labels, keep: [?_initial.dietaryLabelId]);
    final tagOptions = selectableLabels(tags, keep: _initial.tagIds);

    final fields = <Widget>[
      if (item != null && rid != null)
        ImagePickerField(
          purpose: ImagePurpose.item,
          restaurantId: rid,
          targetPath: 'restaurants/$rid/items/${item.id}',
          label: l10n.menuFieldPhoto,
          value: item.image,
          onRemove: () => ref.read(menuRepositoryProvider).updateItem(
            rid,
            item.id,
            {MenuFields.image: null},
          ),
        )
      else
        Card.outlined(
          margin: EdgeInsetsDirectional.zero,
          child: ListTile(
            leading: const Icon(Icons.add_a_photo_outlined),
            title: Text(l10n.menuFieldPhoto),
            subtitle: Text(l10n.menuPhotoAfterSave),
          ),
        ),
      TextFormField(
        key: ItemEditorKeys.name,
        controller: _name,
        maxLength: MenuLimits.itemName,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: l10n.menuFieldItemName),
        validator: (v) =>
            (v ?? '').trim().isEmpty ? l10n.menuErrorNameRequired : null,
      ),
      DropdownButtonFormField<String>(
        key: ItemEditorKeys.category,
        value: menu.liveCategory(_categoryId)?.id,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.menuFieldCategory),
        items: [
          for (final c in menu.categories)
            DropdownMenuItem(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        validator: (v) => v == null ? l10n.menuErrorCategoryRequired : null,
        onChanged: (v) => _update(() => _categoryId = v),
      ),
      PriceField(
        key: ItemEditorKeys.price,
        currency: currency,
        label: l10n.menuFieldPrice,
        initialMinor: _initial.priceMinor,
        onChanged: (v) => _update(() => _priceMinor = v),
      ),
      FormField<String>(
        initialValue: _dietaryId,
        validator: (_) =>
            _dietaryId == null ? l10n.menuErrorDietaryRequired : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.menuFieldDietary,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            if (dietary.isEmpty)
              Text(l10n.menuLabelsUnavailable)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in dietary)
                    ChoiceChip(
                      key: ItemEditorKeys.dietary(label.id),
                      avatar: MenuLabelIcon(label: label),
                      showCheckmark: false,
                      label: Text(label.name),
                      selected: _dietaryId == label.id,
                      onSelected: (_) {
                        _update(() => _dietaryId = label.id);
                        field.didChange(label.id);
                      },
                    ),
                ],
              ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  field.errorText!,
                  key: ItemEditorKeys.dietaryError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (tagOptions.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.menuFieldTags,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tagOptions)
                  FilterChip(
                    key: ItemEditorKeys.tag(tag.id),
                    avatar: MenuLabelIcon(label: tag),
                    showCheckmark: false,
                    label: Text(tag.name),
                    selected: _tags.contains(tag.id),
                    onSelected: (v) => _update(
                      () => v ? _tags.add(tag.id) : _tags.remove(tag.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
      TextFormField(
        key: ItemEditorKeys.description,
        controller: _description,
        maxLength: MenuLimits.itemDescription,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: l10n.menuFieldDescriptionOptional,
        ),
      ),
      Column(
        children: [
          SwitchListTile(
            key: ItemEditorKeys.available,
            contentPadding: EdgeInsetsDirectional.zero,
            value: _available,
            onChanged: (v) => _update(() => _available = v),
            title: Text(l10n.menuFieldAvailable),
            subtitle: Text(l10n.menuFieldAvailableHelp),
          ),
          SwitchListTile(
            key: ItemEditorKeys.featured,
            contentPadding: EdgeInsetsDirectional.zero,
            value: _featured,
            onChanged: (v) => _update(() => _featured = v),
            title: Text(l10n.menuFieldFeatured),
            subtitle: Text(l10n.menuFieldFeaturedHelp),
          ),
        ],
      ),
      if (item != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: ItemEditorKeys.delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: _saving ? null : () => _delete(item),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.menuDeleteItem),
          ),
        ),
    ];

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            // Not a lazy list: Form.validate() only checks fields that
            // are built, so every field must stay mounted.
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    fields[i],
                  ],
                ],
              ),
            ),
          ),
          Material(
            elevation: 3,
            color: theme.colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dirty ? l10n.menuUnsaved : '',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      key: ItemEditorKeys.close,
                      onPressed: _saving
                          ? null
                          : () async {
                              // Ask first when there are unsaved edits.
                              if (!await confirmDiscardEdits(context, ref) ||
                                  !mounted) {
                                return;
                              }
                              ref.read(editorDirtyProvider.notifier).set(false);
                              widget.onDone();
                            },
                      child: Text(
                        _dirty ? core.actionCancel : l10n.actionClose,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      key: ItemEditorKeys.save,
                      label: item == null ? l10n.actionAdd : l10n.actionSave,
                      loading: _saving,
                      onPressed: item == null || _dirty ? _save : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks before throwing away unsaved item edits. True when it's fine to
/// leave.
Future<bool> confirmDiscardEdits(BuildContext context, WidgetRef ref) async {
  if (!ref.read(editorDirtyProvider)) return true;
  final l10n = AppLocalizations.of(context);
  final ok = await showConfirmDialog(
    context,
    title: l10n.menuDiscardTitle,
    message: l10n.menuDiscardMessage,
    confirmLabel: l10n.actionDiscard,
    cancelLabel: l10n.menuKeepEditing,
    destructive: true,
  );
  if (ok) ref.read(editorDirtyProvider.notifier).set(false);
  return ok;
}
