import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:owner_app/features/menu/data/menu_repository.dart';

const dietaryLabels = [
  MenuLabel(
    id: 'vegetarian',
    kind: MenuLabelKind.dietary,
    name: 'Vegetarian',
    icon: 'veg',
    sort: 10,
  ),
  MenuLabel(
    id: 'non-vegetarian',
    kind: MenuLabelKind.dietary,
    name: 'Non-vegetarian',
    icon: 'nonVeg',
    sort: 20,
  ),
  MenuLabel(
    id: 'vegan',
    kind: MenuLabelKind.dietary,
    name: 'Vegan',
    icon: 'vegan',
    sort: 30,
  ),
  MenuLabel(
    id: 'contains-egg',
    kind: MenuLabelKind.dietary,
    name: 'Contains egg',
    icon: 'egg',
    sort: 40,
  ),
];

const itemTags = [
  MenuLabel(
    id: 'spicy',
    kind: MenuLabelKind.tag,
    name: 'Spicy',
    icon: 'spicy',
    sort: 10,
  ),
  MenuLabel(
    id: 'bestseller',
    kind: MenuLabelKind.tag,
    name: 'Bestseller',
    icon: 'bestseller',
    sort: 20,
  ),
  MenuLabel(
    id: 'chefs-special',
    kind: MenuLabelKind.tag,
    name: "Chef's special",
    icon: 'chefsSpecial',
    sort: 30,
  ),
  MenuLabel(id: 'new', kind: MenuLabelKind.tag, name: 'New', sort: 40),
];

FirebaseFunctionsException callableError(
  String code, [
  Map<String, Object?> extra = const {},
]) => FirebaseFunctionsException(
  message: code,
  code: 'failed-precondition',
  details: {...extra, 'code': code},
);

/// A sample menu: Starters (2 items, one sold out) and Mains (1 item).
FakeMenuRepository sampleMenu() => FakeMenuRepository(
  categories: [
    const MenuCategory(id: 'c1', name: 'Starters', sequence: 1000),
    const MenuCategory(id: 'c2', name: 'Mains', sequence: 2000),
  ],
  items: [
    const MenuItem(
      id: 'i1',
      categoryId: 'c1',
      name: 'Paneer tikka',
      priceMinor: 24900,
      dietaryLabelId: 'vegetarian',
      tagIds: ['spicy'],
      sequence: 1000,
    ),
    const MenuItem(
      id: 'i2',
      categoryId: 'c1',
      name: 'Chicken 65',
      priceMinor: 27900,
      dietaryLabelId: 'non-vegetarian',
      available: false,
      sequence: 2000,
    ),
    const MenuItem(
      id: 'i3',
      categoryId: 'c2',
      name: 'Veg biryani',
      priceMinor: 29900,
      dietaryLabelId: 'vegan',
      featured: true,
      sequence: 1000,
    ),
  ],
);

/// In-memory menu with the server behaviour the screens depend on.
class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository({
    List<MenuCategory> categories = const [],
    List<MenuItem> items = const [],
    this.labels = dietaryLabels,
    this.tags = itemTags,
  }) : categories = [...categories],
       items = [...items];

  List<MenuCategory> categories;
  List<MenuItem> items;
  final List<MenuLabel> labels;
  final List<MenuLabel> tags;

  /// Every call, as `name: args`.
  final calls = <String>[];
  final updates = <String, List<Map<String, Object?>>>{};
  final reorders = <Map<String, int>>[];
  final createdItems = <NewItem>[];

  /// Thrown once by the next call.
  Object? nextError;

  /// When set, `setAvailability` waits for it (to see the optimistic state).
  Completer<void>? availabilityGate;

  int _ids = 100;
  final _categoryEvents = StreamController<List<MenuCategory>>.broadcast();
  final _itemEvents = StreamController<List<MenuItem>>.broadcast();

  void _emit() {
    _categoryEvents.add([...categories]);
    _itemEvents.add([...items]);
  }

  void _maybeThrow() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  @override
  Stream<List<MenuCategory>> watchCategories(String restaurantId) async* {
    yield [...categories];
    yield* _categoryEvents.stream;
  }

  @override
  Stream<List<MenuItem>> watchItems(String restaurantId) async* {
    yield [...items];
    yield* _itemEvents.stream;
  }

  @override
  Stream<List<MenuLabel>> watchLabels(MenuLabelKind kind) =>
      Stream.value(kind == MenuLabelKind.dietary ? labels : tags);

  @override
  Future<String> createCategory(
    String restaurantId, {
    required String name,
    String description = '',
    bool active = true,
  }) async {
    calls.add('createCategory: $name');
    _maybeThrow();
    final id = 'c${_ids++}';
    final seq = categories.fold(0, (m, c) => c.sequence > m ? c.sequence : m);
    categories.add(
      MenuCategory(
        id: id,
        name: name,
        description: description,
        active: active,
        sequence: seq + 1000,
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<String> createItem(String restaurantId, NewItem item) async {
    calls.add('createItem: ${item.name}');
    _maybeThrow();
    createdItems.add(item);
    final id = 'i${_ids++}';
    items.add(
      MenuItem(
        id: id,
        categoryId: item.categoryId,
        name: item.name,
        description: item.description,
        priceMinor: item.priceMinor,
        dietaryLabelId: item.dietaryLabelId,
        tagIds: item.tagIds,
        available: item.available,
        featured: item.featured,
        sequence: 99000,
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> updateCategory(
    String restaurantId,
    String categoryId,
    Map<String, Object?> fields,
  ) async {
    calls.add('updateCategory: $categoryId');
    _maybeThrow();
    (updates[categoryId] ??= []).add(fields);
    categories = [
      for (final c in categories)
        c.id == categoryId
            ? c.copyWith(
                name: fields[MenuFields.name] as String?,
                description: fields[MenuFields.description] as String?,
                active: fields[MenuFields.active] as bool?,
                sequence: fields[MenuFields.sequence] as int?,
              )
            : c,
    ];
    _emit();
  }

  @override
  Future<void> updateItem(
    String restaurantId,
    String itemId,
    Map<String, Object?> fields,
  ) async {
    calls.add('updateItem: $itemId');
    _maybeThrow();
    (updates[itemId] ??= []).add(fields);
    items = [
      for (final i in items)
        i.id == itemId
            ? MenuItem(
                id: i.id,
                categoryId: i.categoryId,
                name: fields[MenuFields.name] as String? ?? i.name,
                description:
                    fields[MenuFields.description] as String? ?? i.description,
                priceMinor:
                    fields[MenuFields.priceMinor] as int? ?? i.priceMinor,
                dietaryLabelId:
                    fields[MenuFields.dietaryLabelId] as String? ??
                    i.dietaryLabelId,
                tagIds: fields[MenuFields.tagIds] as List<String>? ?? i.tagIds,
                available: fields[MenuFields.available] as bool? ?? i.available,
                featured: fields[MenuFields.featured] as bool? ?? i.featured,
                sequence: i.sequence,
              )
            : i,
    ];
    _emit();
  }

  @override
  Future<void> setAvailability(
    String restaurantId,
    Iterable<String> itemIds,
    bool available,
  ) async {
    final ids = itemIds.toSet();
    calls.add('setAvailability: ${ids.join(',')}=$available');
    await availabilityGate?.future;
    _maybeThrow();
    items = [
      for (final i in items)
        ids.contains(i.id) ? i.copyWith(available: available) : i,
    ];
    _emit();
  }

  @override
  Future<void> reorder(
    String restaurantId,
    MenuCollection kind,
    Map<String, int> sequences,
  ) async {
    calls.add('reorder: ${kind.name}');
    _maybeThrow();
    reorders.add(sequences);
    if (kind == MenuCollection.items) {
      items = [
        for (final i in items)
          sequences.containsKey(i.id)
              ? i.copyWith(sequence: sequences[i.id])
              : i,
      ];
    } else {
      categories = [
        for (final c in categories)
          sequences.containsKey(c.id)
              ? c.copyWith(sequence: sequences[c.id])
              : c,
      ];
    }
    _emit();
  }

  MenuCategory _deleted(MenuCategory c) => MenuCategory(
    id: c.id,
    name: c.name,
    sequence: c.sequence,
    active: c.active,
    deletedAt: DateTime.now(),
  );

  MenuItem _deletedItem(MenuItem i, {String? withCategory}) => MenuItem(
    id: i.id,
    categoryId: i.categoryId,
    name: i.name,
    priceMinor: i.priceMinor,
    dietaryLabelId: i.dietaryLabelId,
    sequence: i.sequence,
    deletedAt: DateTime.now(),
    deletedWith: withCategory,
  );

  @override
  Future<void> deleteCategory(
    String restaurantId,
    String categoryId, {
    required DeleteCategoryMode mode,
    String? targetCategoryId,
    String? confirmName,
  }) async {
    calls.add(
      'deleteCategory: $categoryId ${mode.name} '
      '${targetCategoryId ?? ''}${confirmName ?? ''}',
    );
    _maybeThrow();
    categories = [
      for (final c in categories) c.id == categoryId ? _deleted(c) : c,
    ];
    items = [
      for (final i in items)
        if (i.categoryId != categoryId || i.isDeleted)
          i
        else if (mode == DeleteCategoryMode.move)
          i.copyWith(categoryId: targetCategoryId)
        else
          _deletedItem(i, withCategory: categoryId),
    ];
    _emit();
  }

  @override
  Future<void> deleteItems(String restaurantId, List<String> itemIds) async {
    calls.add('deleteItems: ${itemIds.join(',')}');
    _maybeThrow();
    items = [
      for (final i in items) itemIds.contains(i.id) ? _deletedItem(i) : i,
    ];
    _emit();
  }

  @override
  Future<void> moveItems(
    String restaurantId,
    List<String> itemIds,
    String targetCategoryId,
  ) async {
    calls.add('moveItems: ${itemIds.join(',')}->$targetCategoryId');
    _maybeThrow();
    items = [
      for (final i in items)
        itemIds.contains(i.id) ? i.copyWith(categoryId: targetCategoryId) : i,
    ];
    _emit();
  }

  @override
  Future<void> restore(
    String restaurantId, {
    required bool category,
    required String id,
    String? targetCategoryId,
  }) async {
    calls.add(
      'restore: ${category ? 'category' : 'item'} $id${targetCategoryId == null ? '' : '->$targetCategoryId'}',
    );
    _maybeThrow();
    if (category) {
      categories = [
        for (final c in categories)
          c.id == id
              ? MenuCategory(id: c.id, name: c.name, sequence: c.sequence)
              : c,
      ];
    }
    items = [
      for (final i in items)
        if ((!category && i.id == id) || (category && i.deletedWith == id))
          MenuItem(
            id: i.id,
            categoryId: targetCategoryId ?? i.categoryId,
            name: i.name,
            priceMinor: i.priceMinor,
            dietaryLabelId: i.dietaryLabelId,
            sequence: i.sequence,
          )
        else
          i,
    ];
    _emit();
  }
}
