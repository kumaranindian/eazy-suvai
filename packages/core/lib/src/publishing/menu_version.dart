import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One entry of `restaurants/{rid}.versionHistory` (M06): a published
/// version, newest first, at most 10 (FR-096). Written only by
/// `publishMenu` and `rollbackMenu`, in the same transaction as
/// `versions/{n}`, so the history screen does not have to download every
/// snapshot.
@immutable
class MenuVersionEntry {
  const MenuVersionEntry({
    required this.n,
    required this.publishedAt,
    this.publishedBy = '',
    this.rollbackOf,
    this.added = 0,
    this.changed = 0,
    this.removed = 0,
    this.profileChanged = false,
    this.themeChanged = false,
  });

  static MenuVersionEntry? fromMap(Object? value) {
    if (value is! Map || value['n'] is! int) return null;
    final summary = value['summary'] is Map
        ? value['summary'] as Map
        : const {};
    int count(String key) => summary[key] is int ? summary[key] as int : 0;
    final at = value['publishedAt'];
    return MenuVersionEntry(
      n: value['n'] as int,
      publishedAt: at is Timestamp
          ? at.toDate()
          : (at is DateTime ? at : DateTime.fromMillisecondsSinceEpoch(0)),
      publishedBy: value['publishedBy'] as String? ?? '',
      rollbackOf: value['rollbackOf'] as int?,
      added: count('added'),
      changed: count('changed'),
      removed: count('removed'),
      profileChanged: summary['profileChanged'] == true,
      themeChanged: summary['themeChanged'] == true,
    );
  }

  /// Reads the whole list, newest first.
  static List<MenuVersionEntry> listFrom(Object? value) {
    if (value is! List) return const [];
    return [
      for (final v in value)
        if (fromMap(v) case final e?) e,
    ]..sort((a, b) => b.n.compareTo(a.n));
  }

  /// Version number.
  final int n;

  /// UTC.
  final DateTime publishedAt;

  /// The uid who published.
  final String publishedBy;

  /// Set when this version re-published an earlier one (a rollback).
  final int? rollbackOf;
  final int added;
  final int changed;
  final int removed;
  final bool profileChanged;
  final bool themeChanged;

  bool get isRollback => rollbackOf != null;
}
