import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../media/image_object.dart';

/// Field limits for menu content (FR-016, FR-022). Keep in sync with
/// `MENU_LIMITS` in `functions/src/menu/schemas.ts` and `firestore.rules`.
abstract final class MenuLimits {
  static const categoryName = 60;
  static const categoryDescription = 250;
  static const itemName = 80;
  static const itemDescription = 500;

  /// 999,999,999 minor units: INR 9,999,999.99 or KWD 999,999.999.
  static const maxPriceMinor = 999999999;
  static const maxTags = 10;

  /// Gap between `sequence` values of neighbours (M04 plan).
  static const sequenceGap = 1000;

  /// Days a soft-deleted category or item can be restored (FR-098).
  static const restoreDays = 30;
}

/// Firestore field names of `categories/{cid}` and `items/{iid}`.
abstract final class MenuFields {
  static const name = 'name';
  static const description = 'description';
  static const image = 'image';
  static const sequence = 'sequence';
  static const active = 'active';
  static const updatedAt = 'updatedAt';
  static const priceMinor = 'priceMinor';
  static const dietaryLabelId = 'dietaryLabelId';
  static const tagIds = 'tagIds';
  static const available = 'available';
  static const featured = 'featured';
}

DateTime? _time(Object? v) =>
    v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

int _int(Object? v, [int fallback = 0]) => v is int ? v : fallback;

/// When a soft-deleted document stops being restorable.
DateTime? _restoreUntil(DateTime? deletedAt) =>
    deletedAt?.add(const Duration(days: MenuLimits.restoreDays));

/// `restaurants/{rid}/categories/{cid}` (FR-016, architecture §4.2).
@immutable
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.image,
    this.sequence = 0,
    this.active = true,
    this.deletedAt,
    this.hiddenOverLimit = false,
  });

  factory MenuCategory.fromMap(String id, Map<String, dynamic> data) =>
      MenuCategory(
        id: id,
        name: data['name'] as String? ?? '',
        description: data['description'] as String? ?? '',
        image: ImageObject.fromMap(data['image']),
        sequence: _int(data['sequence']),
        active: data['active'] != false,
        deletedAt: _time(data['deletedAt']),
        hiddenOverLimit: data['hiddenOverLimit'] == true,
      );

  final String id;
  final String name;
  final String description;
  final ImageObject? image;
  final int sequence;

  /// Inactive categories and their items are not shown publicly (FR-020).
  final bool active;

  /// Set when soft-deleted (FR-098).
  final DateTime? deletedAt;

  /// Hidden after a downgrade (FR-101, M10); written by Functions only.
  final bool hiddenOverLimit;

  bool get isDeleted => deletedAt != null;

  /// Last moment it can be restored, for deleted categories.
  DateTime? get restoreUntil => _restoreUntil(deletedAt);

  MenuCategory copyWith({
    String? name,
    String? description,
    int? sequence,
    bool? active,
  }) => MenuCategory(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    image: image,
    sequence: sequence ?? this.sequence,
    active: active ?? this.active,
    deletedAt: deletedAt,
    hiddenOverLimit: hiddenOverLimit,
  );

  @override
  bool operator ==(Object other) =>
      other is MenuCategory &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.image?.path == image?.path &&
      other.image?.status == image?.status &&
      other.sequence == sequence &&
      other.active == active &&
      other.deletedAt == deletedAt &&
      other.hiddenOverLimit == hiddenOverLimit;

  @override
  int get hashCode =>
      Object.hash(id, name, sequence, active, deletedAt, hiddenOverLimit);
}

/// `restaurants/{rid}/items/{iid}` (FR-022, architecture §4.2).
@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description = '',
    this.image,
    required this.priceMinor,
    required this.dietaryLabelId,
    this.tagIds = const [],
    this.available = true,
    this.featured = false,
    this.sequence = 0,
    this.hiddenOverLimit = false,
    this.deletedAt,
    this.deletedWith,
    this.updatedAt,
  });

  factory MenuItem.fromMap(String id, Map<String, dynamic> data) => MenuItem(
    id: id,
    categoryId: data['categoryId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    description: data['description'] as String? ?? '',
    image: ImageObject.fromMap(data['image']),
    priceMinor: _int(data['priceMinor']),
    dietaryLabelId: data['dietaryLabelId'] as String? ?? '',
    tagIds: [
      for (final t in (data['tagIds'] as List?) ?? const [])
        if (t is String) t,
    ],
    available: data['available'] != false,
    featured: data['featured'] == true,
    sequence: _int(data['sequence']),
    hiddenOverLimit: data['hiddenOverLimit'] == true,
    deletedAt: _time(data['deletedAt']),
    deletedWith: data['deletedWith'] as String?,
    updatedAt: _time(data['updatedAt']),
  );

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final ImageObject? image;

  /// Integer minor units of the restaurant's currency (FR-029, BR-019).
  final int priceMinor;
  final String dietaryLabelId;
  final List<String> tagIds;

  /// Live availability (FR-025, FR-095).
  final bool available;
  final bool featured;
  final int sequence;

  /// Hidden after a plan downgrade (FR-101, M10).
  final bool hiddenOverLimit;
  final DateTime? deletedAt;

  /// The category it was deleted with, if any (restored together).
  final String? deletedWith;
  final DateTime? updatedAt;

  bool get isDeleted => deletedAt != null;

  DateTime? get restoreUntil => _restoreUntil(deletedAt);

  MenuItem copyWith({bool? available, int? sequence, String? categoryId}) =>
      MenuItem(
        id: id,
        categoryId: categoryId ?? this.categoryId,
        name: name,
        description: description,
        image: image,
        priceMinor: priceMinor,
        dietaryLabelId: dietaryLabelId,
        tagIds: tagIds,
        available: available ?? this.available,
        featured: featured,
        sequence: sequence ?? this.sequence,
        hiddenOverLimit: hiddenOverLimit,
        deletedAt: deletedAt,
        deletedWith: deletedWith,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is MenuItem &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.name == name &&
      other.description == description &&
      other.image?.path == image?.path &&
      other.image?.status == image?.status &&
      other.priceMinor == priceMinor &&
      other.dietaryLabelId == dietaryLabelId &&
      listEquals(other.tagIds, tagIds) &&
      other.available == available &&
      other.featured == featured &&
      other.sequence == sequence &&
      other.hiddenOverLimit == hiddenOverLimit &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode =>
      Object.hash(id, categoryId, name, priceMinor, available, sequence);
}

/// Kind of platform-managed label (FR-104).
enum MenuLabelKind {
  /// `dietaryLabels/{id}`: exactly one per item (FR-023).
  dietary('dietaryLabels'),

  /// `itemTags/{id}`: zero or more per item (FR-033).
  tag('itemTags');

  const MenuLabelKind(this.collection);

  final String collection;
}

/// A platform-managed dietary label or item tag (FR-023, FR-033, FR-104).
///
/// [icon] is a key such as `veg`, `nonVeg`, `vegan`, `egg`, `spicy`; the
/// widgets in `dietary_icon.dart` draw it. [name] is platform data shown as
/// the text label next to the icon, so meaning never depends on colour.
@immutable
class MenuLabel {
  const MenuLabel({
    required this.id,
    required this.kind,
    required this.name,
    this.icon = '',
    this.color,
    this.sort = 0,
    this.retired = false,
  });

  factory MenuLabel.fromMap(
    MenuLabelKind kind,
    String id,
    Map<String, dynamic> data,
  ) => MenuLabel(
    id: id,
    kind: kind,
    name: data['name'] as String? ?? id,
    icon: data['icon'] as String? ?? '',
    color: parseHexColor(data['color']),
    sort: _int(data['sort']),
    retired: data['retired'] == true,
  );

  final String id;
  final MenuLabelKind kind;
  final String name;
  final String icon;

  /// ARGB colour of the symbol, if set.
  final int? color;
  final int sort;

  /// Retired entries stay on existing items but are not offered for new
  /// choices (FR-104).
  final bool retired;

  @override
  bool operator ==(Object other) =>
      other is MenuLabel &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.icon == icon &&
      other.color == color &&
      other.sort == sort &&
      other.retired == retired;

  @override
  int get hashCode => Object.hash(id, kind, name, icon, color, sort, retired);
}

/// Parses `#RRGGBB` to an opaque ARGB int, or null.
int? parseHexColor(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value);
  if (m == null) return null;
  return 0xFF000000 | int.parse(m.group(1)!, radix: 16);
}

/// Labels a picker offers: active ones in sort order, plus [keep] (the
/// item's current choice) even if retired (FR-104).
List<MenuLabel> selectableLabels(
  Iterable<MenuLabel> labels, {
  Iterable<String> keep = const [],
}) {
  final keepSet = keep.toSet();
  return [
    for (final l in labels)
      if (!l.retired || keepSet.contains(l.id)) l,
  ]..sort((a, b) {
    final s = a.sort.compareTo(b.sort);
    return s != 0 ? s : a.name.compareTo(b.name);
  });
}
