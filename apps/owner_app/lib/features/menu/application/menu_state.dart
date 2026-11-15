import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../restaurant/data/restaurant_repository.dart';
import '../data/menu_repository.dart';

/// The owner's menu as the screens use it: live categories and items in
/// display order, plus the soft-deleted ones for Recently deleted.
@immutable
class MenuData {
  MenuData({
    required List<MenuCategory> categories,
    required List<MenuItem> items,
  }) : categories = [
         for (final c in categories)
           if (!c.isDeleted) c,
       ]..sort(_byCategorySequence),
       deletedCategories = [
         for (final c in categories)
           if (c.isDeleted) c,
       ]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!)),
       deletedItems = [
         for (final i in items)
           if (i.isDeleted) i,
       ]..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!)),
       _allCategories = {for (final c in categories) c.id: c} {
    final order = {
      for (var i = 0; i < this.categories.length; i++) this.categories[i].id: i,
    };
    final live = [
      for (final i in items)
        if (!i.isDeleted) i,
    ];
    live.sort((a, b) {
      final c = (order[a.categoryId] ?? 1 << 30).compareTo(
        order[b.categoryId] ?? 1 << 30,
      );
      return c != 0 ? c : _byItemSequence(a, b);
    });
    this.items = live;
    for (final i in live) {
      (_byCategory[i.categoryId] ??= []).add(i);
    }
  }

  static int _byCategorySequence(MenuCategory a, MenuCategory b) =>
      compareSequenced(
        (id: a.id, sequence: a.sequence),
        (id: b.id, sequence: b.sequence),
      );

  static int _byItemSequence(MenuItem a, MenuItem b) => compareSequenced(
    (id: a.id, sequence: a.sequence),
    (id: b.id, sequence: b.sequence),
  );

  /// Non-deleted categories, by `sequence`.
  final List<MenuCategory> categories;

  /// Non-deleted items, by category order then `sequence`.
  late final List<MenuItem> items;

  /// Soft-deleted, newest first.
  final List<MenuCategory> deletedCategories;
  final List<MenuItem> deletedItems;

  final Map<String, MenuCategory> _allCategories;
  final Map<String, List<MenuItem>> _byCategory = {};

  /// Non-deleted items of [categoryId], by `sequence`.
  List<MenuItem> itemsIn(String categoryId) =>
      _byCategory[categoryId] ?? const [];

  /// Any category, deleted or not.
  MenuCategory? category(String id) => _allCategories[id];

  MenuCategory? liveCategory(String? id) {
    final c = id == null ? null : _allCategories[id];
    return c == null || c.isDeleted ? null : c;
  }

  MenuItem? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Items deleted together with [categoryId] (restored with it).
  List<MenuItem> deletedWith(String categoryId) => [
    for (final i in deletedItems)
      if (i.deletedWith == categoryId) i,
  ];

  /// Deleted items listed on their own in Recently deleted.
  List<MenuItem> get deletedItemsAlone => [
    for (final i in deletedItems)
      if (i.deletedWith == null || category(i.deletedWith!)?.isDeleted != true)
        i,
  ];
}

final _categoriesStreamProvider = StreamProvider<List<MenuCategory>>((ref) {
  final rid = ref.watch(currentRestaurantIdProvider);
  if (rid == null) return const Stream.empty();
  return ref.watch(menuRepositoryProvider).watchCategories(rid);
});

final _itemsStreamProvider = StreamProvider<List<MenuItem>>((ref) {
  final rid = ref.watch(currentRestaurantIdProvider);
  if (rid == null) return const Stream.empty();
  return ref.watch(menuRepositoryProvider).watchItems(rid);
});

/// Platform dietary labels, in sort order (FR-023).
final dietaryLabelsProvider = StreamProvider<List<MenuLabel>>(
  (ref) => ref
      .watch(menuRepositoryProvider)
      .watchLabels(MenuLabelKind.dietary)
      .map((l) => [...l]..sort((a, b) => a.sort.compareTo(b.sort))),
);

/// Platform item tags, in sort order (FR-033).
final itemTagsProvider = StreamProvider<List<MenuLabel>>(
  (ref) => ref
      .watch(menuRepositoryProvider)
      .watchLabels(MenuLabelKind.tag)
      .map((l) => [...l]..sort((a, b) => a.sort.compareTo(b.sort))),
);

/// Changes shown before Firestore confirms them (optimistic UI): item
/// availability and the order of categories and items. Cleared when the
/// write finishes; on failure the stream's value shows again (rollback).
@immutable
class PendingChanges {
  const PendingChanges({
    this.available = const {},
    this.itemSequence = const {},
    this.categorySequence = const {},
  });

  final Map<String, bool> available;
  final Map<String, int> itemSequence;
  final Map<String, int> categorySequence;

  bool get isEmpty =>
      available.isEmpty && itemSequence.isEmpty && categorySequence.isEmpty;
}

class PendingChangesNotifier extends Notifier<PendingChanges> {
  @override
  PendingChanges build() => const PendingChanges();

  MenuRepository get _repo => ref.read(menuRepositoryProvider);
  String? get _rid => ref.read(currentRestaurantIdProvider);

  /// Switches availability at once, then writes it (FR-025, FR-095).
  /// Rethrows a failed write after rolling back.
  Future<void> setAvailability(Iterable<String> itemIds, bool value) async {
    final rid = _rid;
    final ids = itemIds.toList();
    if (rid == null || ids.isEmpty) return;
    state = PendingChanges(
      available: {...state.available, for (final id in ids) id: value},
      itemSequence: state.itemSequence,
      categorySequence: state.categorySequence,
    );
    try {
      await _repo.setAvailability(rid, ids, value);
    } finally {
      _clear(available: ids);
    }
  }

  /// Applies new sequences at once, then writes them (FR-019, FR-028).
  Future<void> reorder(MenuCollection kind, Map<String, int> sequences) async {
    final rid = _rid;
    if (rid == null || sequences.isEmpty) return;
    final items = kind == MenuCollection.items;
    state = PendingChanges(
      available: state.available,
      itemSequence: items
          ? {...state.itemSequence, ...sequences}
          : state.itemSequence,
      categorySequence: items
          ? state.categorySequence
          : {...state.categorySequence, ...sequences},
    );
    try {
      await _repo.reorder(rid, kind, sequences);
    } finally {
      _clear(
        itemSequence: items ? sequences.keys : const [],
        categorySequence: items ? const [] : sequences.keys,
      );
    }
  }

  void _clear({
    Iterable<String> available = const [],
    Iterable<String> itemSequence = const [],
    Iterable<String> categorySequence = const [],
  }) {
    if (!ref.mounted) return;
    Map<String, T> without<T>(Map<String, T> m, Iterable<String> keys) {
      final s = keys.toSet();
      return {
        for (final e in m.entries)
          if (!s.contains(e.key)) e.key: e.value,
      };
    }

    state = PendingChanges(
      available: without(state.available, available),
      itemSequence: without(state.itemSequence, itemSequence),
      categorySequence: without(state.categorySequence, categorySequence),
    );
  }
}

final pendingChangesProvider =
    NotifierProvider<PendingChangesNotifier, PendingChanges>(
      PendingChangesNotifier.new,
    );

/// The menu with pending (optimistic) changes applied.
final menuDataProvider = Provider<AsyncValue<MenuData>>((ref) {
  final categories = ref.watch(_categoriesStreamProvider);
  final items = ref.watch(_itemsStreamProvider);
  final pending = ref.watch(pendingChangesProvider);
  if (categories.hasError) {
    return AsyncError(categories.error!, categories.stackTrace!);
  }
  if (items.hasError) return AsyncError(items.error!, items.stackTrace!);
  final c = categories.value;
  final i = items.value;
  if (c == null || i == null) return const AsyncLoading();
  if (pending.isEmpty) return AsyncData(MenuData(categories: c, items: i));
  return AsyncData(
    MenuData(
      categories: [
        for (final cat in c)
          pending.categorySequence.containsKey(cat.id)
              ? cat.copyWith(sequence: pending.categorySequence[cat.id])
              : cat,
      ],
      items: [
        for (final it in i)
          if (pending.available.containsKey(it.id) ||
              pending.itemSequence.containsKey(it.id))
            it.copyWith(
              available: pending.available[it.id],
              sequence: pending.itemSequence[it.id],
            )
          else
            it,
      ],
    ),
  );
});

/// A simple value holder for UI state shared between panes.
class ValueNotifierOf<T> extends Notifier<T> {
  ValueNotifierOf(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

/// Sentinel for the "All items" entry of the category list.
const allItemsId = '*';

/// The category whose items the wide layouts show ([allItemsId] for all).
final selectedCategoryProvider =
    NotifierProvider<ValueNotifierOf<String?>, String?>(
      () => ValueNotifierOf<String?>(null),
    );

/// What the item editor shows on wide layouts.
@immutable
class EditorTarget {
  const EditorTarget.item(String this.itemId) : newInCategory = null;
  const EditorTarget.create(this.newInCategory) : itemId = null;

  final String? itemId;

  /// Category preselected for a new item.
  final String? newInCategory;

  bool get isNew => itemId == null;

  @override
  bool operator ==(Object other) =>
      other is EditorTarget &&
      other.itemId == itemId &&
      other.newInCategory == newInCategory;

  @override
  int get hashCode => Object.hash(itemId, newInCategory);
}

final editorTargetProvider =
    NotifierProvider<ValueNotifierOf<EditorTarget?>, EditorTarget?>(
      () => ValueNotifierOf<EditorTarget?>(null),
    );

/// True while the open item editor has unsaved changes.
final editorDirtyProvider = NotifierProvider<ValueNotifierOf<bool>, bool>(
  () => ValueNotifierOf<bool>(false),
);

/// Search and filters of the item list.
///
/// Within a group the chips are alternatives (Veg or Egg); the groups
/// narrow each other (Veg or Egg, and Spicy).
@immutable
class ItemFilter {
  const ItemFilter({
    this.query = '',
    this.soldOut = false,
    this.featured = false,
    this.labelIds = const {},
    this.tagIds = const {},
  });

  final String query;

  /// Only unavailable items (FRD §5.4).
  final bool soldOut;
  final bool featured;

  /// Dietary labels; an item matches when it has any of them.
  final Set<String> labelIds;

  /// Tags; an item matches when it has any of them.
  final Set<String> tagIds;

  bool get isActive =>
      query.trim().isNotEmpty ||
      soldOut ||
      featured ||
      labelIds.isNotEmpty ||
      tagIds.isNotEmpty;

  bool matches(MenuItem item) {
    if (soldOut && item.available) return false;
    if (featured && !item.featured) return false;
    if (labelIds.isNotEmpty && !labelIds.contains(item.dietaryLabelId)) {
      return false;
    }
    if (tagIds.isNotEmpty && !item.tagIds.any(tagIds.contains)) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.name.toLowerCase().contains(q) ||
        item.description.toLowerCase().contains(q);
  }

  /// Adds or removes one dietary label.
  ItemFilter toggleLabel(String id, bool on) =>
      copyWith(labelIds: _toggle(labelIds, id, on));

  /// Adds or removes one tag.
  ItemFilter toggleTag(String id, bool on) =>
      copyWith(tagIds: _toggle(tagIds, id, on));

  static Set<String> _toggle(Set<String> set, String id, bool on) =>
      on ? {...set, id} : ({...set}..remove(id));

  ItemFilter copyWith({
    String? query,
    bool? soldOut,
    bool? featured,
    Set<String>? labelIds,
    Set<String>? tagIds,
  }) => ItemFilter(
    query: query ?? this.query,
    soldOut: soldOut ?? this.soldOut,
    featured: featured ?? this.featured,
    labelIds: labelIds ?? this.labelIds,
    tagIds: tagIds ?? this.tagIds,
  );
}

final itemFilterProvider =
    NotifierProvider<ValueNotifierOf<ItemFilter>, ItemFilter>(
      () => ValueNotifierOf<ItemFilter>(const ItemFilter()),
    );

/// Items selected for a bulk action (wide layouts).
final bulkSelectionProvider =
    NotifierProvider<ValueNotifierOf<Set<String>>, Set<String>>(
      () => ValueNotifierOf<Set<String>>(const {}),
    );
