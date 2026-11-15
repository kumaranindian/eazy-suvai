import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform themes and fonts (M05, FR-056, FR-059). Read-only for owners;
/// admins manage them through Functions (M11).
abstract class ThemeRepository {
  /// `themes/*`, retired ones included (a restaurant may still use one).
  Stream<List<ThemePreset>> watchThemes();

  /// `config/platform.fonts`; null when the document or field is missing.
  Stream<List<String>?> watchFonts();
}

class FirestoreThemeRepository implements ThemeRepository {
  FirestoreThemeRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<ThemePreset>> watchThemes() => _db
      .collection('themes')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) ThemePreset.fromMap(d.id, d.data())],
      );

  @override
  Stream<List<String>?> watchFonts() =>
      _db.doc('config/platform').snapshots().map((s) {
        final fonts = s.data()?['fonts'];
        return fonts is List ? fonts.whereType<String>().toList() : null;
      });
}

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => FirestoreThemeRepository(FirebaseFirestore.instance),
);

/// All themes by `sort`, then name.
final themePresetsProvider = StreamProvider<List<ThemePreset>>(
  (ref) => ref
      .watch(themeRepositoryProvider)
      .watchThemes()
      .map(
        (list) => [...list]
          ..sort((a, b) {
            final s = a.sort.compareTo(b.sort);
            return s != 0 ? s : a.name.compareTo(b.name);
          }),
      ),
);

/// The curated fonts; [MenuFonts.defaults] until `config/platform` says
/// otherwise (or when it cannot be read).
final menuFontsProvider = Provider<List<String>>((ref) {
  final fonts = ref.watch(_platformFontsProvider).value;
  return fonts == null || fonts.isEmpty ? MenuFonts.defaults : fonts;
});

final _platformFontsProvider = StreamProvider<List<String>?>(
  (ref) => ref.watch(themeRepositoryProvider).watchFonts(),
);
