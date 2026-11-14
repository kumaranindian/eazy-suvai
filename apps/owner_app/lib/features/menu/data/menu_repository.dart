import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fields of a new item (FR-022). Sent to the `createItem` callable.
class NewItem {
  const NewItem({
    required this.categoryId,
    required this.name,
    this.description = '',
    required this.priceMinor,
    required this.dietaryLabelId,
    this.tagIds = const [],
    this.available = true,
    this.featured = false,
  });

  final String categoryId;
  final String name;
  final String description;
  final int priceMinor;
  final String dietaryLabelId;
  final List<String> tagIds;
  final bool available;
  final bool featured;

  Map<String, Object?> toJson() => {
    'categoryId': categoryId,
    'name': name,
    'description': description,
    'priceMinor': priceMinor,
    'dietaryLabelId': dietaryLabelId,
    'tagIds': tagIds,
    'available': available,
    'featured': featured,
  };
}

/// How `deleteCategory` treats a category's items (FR-018).
enum DeleteCategoryMode { move, deleteAll }

/// Menu content of the owner's restaurant (M04).
///
/// Creating and deleting go through callables (plan limits, BR-011); edits
/// are direct whitelisted updates that stamp `updatedAt` with the server
/// time, as the security rules require.
abstract class MenuRepository {
  /// Every category, deleted ones included (for Recently deleted).
  Stream<List<MenuCategory>> watchCategories(String restaurantId);

  /// Every item, deleted ones included.
  Stream<List<MenuItem>> watchItems(String restaurantId);

  /// Platform dietary labels or item tags (FR-104).
  Stream<List<MenuLabel>> watchLabels(MenuLabelKind kind);

  /// Returns the new category id.
  Future<String> createCategory(
    String restaurantId, {
    required String name,
    String description = '',
    bool active = true,
  });

  /// Returns the new item id.
  Future<String> createItem(String restaurantId, NewItem item);

  /// Whitelisted fields of one category ([MenuFields]).
  Future<void> updateCategory(
    String restaurantId,
    String categoryId,
    Map<String, Object?> fields,
  );

  /// Whitelisted fields of one item ([MenuFields]).
  Future<void> updateItem(
    String restaurantId,
    String itemId,
    Map<String, Object?> fields,
  );

  /// Sets `available` on several items in one batch (FR-025, FR-095).
  Future<void> setAvailability(
    String restaurantId,
    Iterable<String> itemIds,
    bool available,
  );

  /// Writes new `sequence` values in one batch (FR-019, FR-028).
  Future<void> reorder(
    String restaurantId,
    MenuCollection kind,
    Map<String, int> sequences,
  );

  Future<void> deleteCategory(
    String restaurantId,
    String categoryId, {
    required DeleteCategoryMode mode,
    String? targetCategoryId,
    String? confirmName,
  });

  Future<void> deleteItems(String restaurantId, List<String> itemIds);

  Future<void> moveItems(
    String restaurantId,
    List<String> itemIds,
    String targetCategoryId,
  );

  /// Restores a category (with the items deleted with it) or an item.
  Future<void> restore(
    String restaurantId, {
    required bool category,
    required String id,
    String? targetCategoryId,
  });
}

/// Which collection [MenuRepository.reorder] writes.
enum MenuCollection {
  categories('categories'),
  items('items');

  const MenuCollection(this.collection);

  final String collection;
}

class FirestoreMenuRepository implements MenuRepository {
  FirestoreMenuRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String rid, String name) =>
      _db.collection('restaurants/$rid/$name');

  Future<Map<Object?, Object?>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final result = await regionalFunctions
        .httpsCallable(name)
        .call<Map<Object?, Object?>>(data);
    return result.data;
  }

  @override
  Stream<List<MenuCategory>> watchCategories(String restaurantId) =>
      _col(restaurantId, 'categories').snapshots().map(
        (s) => [for (final d in s.docs) MenuCategory.fromMap(d.id, d.data())],
      );

  @override
  Stream<List<MenuItem>> watchItems(String restaurantId) =>
      _col(restaurantId, 'items').snapshots().map(
        (s) => [for (final d in s.docs) MenuItem.fromMap(d.id, d.data())],
      );

  @override
  Stream<List<MenuLabel>> watchLabels(MenuLabelKind kind) => _db
      .collection(kind.collection)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) MenuLabel.fromMap(kind, d.id, d.data()),
        ],
      );

  @override
  Future<String> createCategory(
    String restaurantId, {
    required String name,
    String description = '',
    bool active = true,
  }) async {
    final r = await _call('createCategory', {
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'active': active,
    });
    return r['id']! as String;
  }

  @override
  Future<String> createItem(String restaurantId, NewItem item) async {
    final r = await _call('createItem', {
      'restaurantId': restaurantId,
      ...item.toJson(),
    });
    return r['id']! as String;
  }

  Map<String, Object?> _stamp(Map<String, Object?> fields) => {
    ...fields,
    MenuFields.updatedAt: FieldValue.serverTimestamp(),
  };

  @override
  Future<void> updateCategory(
    String restaurantId,
    String categoryId,
    Map<String, Object?> fields,
  ) => _col(restaurantId, 'categories').doc(categoryId).update(_stamp(fields));

  @override
  Future<void> updateItem(
    String restaurantId,
    String itemId,
    Map<String, Object?> fields,
  ) => _col(restaurantId, 'items').doc(itemId).update(_stamp(fields));

  Future<void> _batch(
    String rid,
    String collection,
    Map<String, Map<String, Object?>> updates,
  ) async {
    final entries = updates.entries.toList();
    // Keep each batch well inside the rules' per-request budget.
    for (var i = 0; i < entries.length; i += 100) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(100)) {
        batch.update(_col(rid, collection).doc(e.key), _stamp(e.value));
      }
      await batch.commit();
    }
  }

  @override
  Future<void> setAvailability(
    String restaurantId,
    Iterable<String> itemIds,
    bool available,
  ) => _batch(restaurantId, 'items', {
    for (final id in itemIds) id: {MenuFields.available: available},
  });

  @override
  Future<void> reorder(
    String restaurantId,
    MenuCollection kind,
    Map<String, int> sequences,
  ) => _batch(restaurantId, kind.collection, {
    for (final e in sequences.entries) e.key: {MenuFields.sequence: e.value},
  });

  @override
  Future<void> deleteCategory(
    String restaurantId,
    String categoryId, {
    required DeleteCategoryMode mode,
    String? targetCategoryId,
    String? confirmName,
  }) => _call('deleteCategory', {
    'restaurantId': restaurantId,
    'categoryId': categoryId,
    'mode': mode.name,
    'targetCategoryId': ?targetCategoryId,
    'confirmName': ?confirmName,
  });

  @override
  Future<void> deleteItems(String restaurantId, List<String> itemIds) =>
      _call('deleteItems', {'restaurantId': restaurantId, 'itemIds': itemIds});

  @override
  Future<void> moveItems(
    String restaurantId,
    List<String> itemIds,
    String targetCategoryId,
  ) => _call('moveItems', {
    'restaurantId': restaurantId,
    'itemIds': itemIds,
    'targetCategoryId': targetCategoryId,
  });

  @override
  Future<void> restore(
    String restaurantId, {
    required bool category,
    required String id,
    String? targetCategoryId,
  }) => _call('restoreDeleted', {
    'restaurantId': restaurantId,
    'kind': category ? 'category' : 'item',
    'id': id,
    'targetCategoryId': ?targetCategoryId,
  });
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => FirestoreMenuRepository(FirebaseFirestore.instance),
);
