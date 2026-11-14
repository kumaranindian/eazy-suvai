import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of `changeSlug` (M03).
class SlugChange {
  const SlugChange({
    required this.slug,
    required this.previousSlug,
    required this.changed,
  });

  factory SlugChange.fromJson(Map<Object?, Object?> json) => SlugChange(
    slug: json['slug']! as String,
    previousSlug: json['previousSlug'] as String? ?? '',
    changed: json['changed'] == true,
  );

  final String slug;
  final String previousSlug;

  /// False for an availability check, or when the slug did not change.
  final bool changed;
}

/// Reads and writes the owner's `restaurants/{rid}` document (M03).
abstract class RestaurantRepository {
  /// The restaurant, live. Emits null if it does not exist.
  Stream<Restaurant?> watch(String restaurantId);

  /// Writes draft profile fields (FR-012). Adds `draftUpdatedAt` with the
  /// server time, as the security rules require. [fields] use the names in
  /// [RestaurantFields] with whole values (for example the full `contact`
  /// map), never dotted paths.
  Future<void> updateDraft(String restaurantId, Map<String, Object?> fields);

  /// Marks the first-run setup wizard as finished or skipped.
  Future<void> completeSetup(String restaurantId);

  /// Checks that [slug] could become this restaurant's menu link, without
  /// changing anything. Throws the `changeSlug` errors (`slug-invalid`,
  /// `slug-reserved`, `slug-taken`).
  Future<SlugChange> checkSlug(String restaurantId, String slug);

  /// Changes the menu link; the old one keeps working (FR-093).
  Future<SlugChange> changeSlug(String restaurantId, String slug);
}

class FirestoreRestaurantRepository implements RestaurantRepository {
  FirestoreRestaurantRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String rid) =>
      _db.doc('restaurants/$rid');

  @override
  Stream<Restaurant?> watch(String restaurantId) =>
      _doc(restaurantId).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Restaurant.fromMap(s.id, data);
      });

  @override
  Future<void> updateDraft(String restaurantId, Map<String, Object?> fields) =>
      _doc(restaurantId).update({
        ...fields,
        RestaurantFields.draftUpdatedAt: FieldValue.serverTimestamp(),
      });

  @override
  Future<void> completeSetup(String restaurantId) => _doc(
    restaurantId,
  ).update({RestaurantFields.setupCompletedAt: FieldValue.serverTimestamp()});

  Future<SlugChange> _call(
    String rid,
    String slug, {
    required bool dryRun,
  }) async {
    final result = await regionalFunctions
        .httpsCallable('changeSlug')
        .call<Map<Object?, Object?>>({
          'restaurantId': rid,
          'slug': slug,
          if (dryRun) 'dryRun': true,
        });
    return SlugChange.fromJson(result.data);
  }

  @override
  Future<SlugChange> checkSlug(String restaurantId, String slug) =>
      _call(restaurantId, slug, dryRun: true);

  @override
  Future<SlugChange> changeSlug(String restaurantId, String slug) =>
      _call(restaurantId, slug, dryRun: false);
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => FirestoreRestaurantRepository(FirebaseFirestore.instance),
);

/// The signed-in owner's restaurant id, from the token claims.
final currentRestaurantIdProvider = Provider<String?>(
  (ref) => ref.watch(authSessionProvider).value?.restaurantId,
);

/// The signed-in owner's restaurant, live. Loading while there is no
/// restaurant id yet.
final currentRestaurantProvider = StreamProvider<Restaurant?>((ref) {
  final rid = ref.watch(currentRestaurantIdProvider);
  if (rid == null) return const Stream.empty();
  return ref.watch(restaurantRepositoryProvider).watch(rid);
});
