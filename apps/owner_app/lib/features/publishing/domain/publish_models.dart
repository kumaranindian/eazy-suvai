import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// Stable problem codes from `publishMenu` (FR-066). Keep in sync with
/// `ProblemCode` in `functions/src/publishing/snapshot.ts`.
enum PublishProblemCode {
  emailNotVerified('email-not-verified'),
  menuEmpty('menu-empty'),
  missingField('missing-field'),
  invalidField('invalid-field'),
  limitExceeded('limit-exceeded'),
  pricesNeedReview('prices-need-review'),
  snapshotTooLarge('snapshot-too-large'),
  unknown('unknown');

  const PublishProblemCode(this.wire);

  final String wire;

  static PublishProblemCode fromWire(Object? value) => values.firstWhere(
    (c) => c.wire == value,
    orElse: () => PublishProblemCode.unknown,
  );
}

/// What a problem is about.
enum ProblemTarget { restaurant, category, item, none }

/// One reason the draft cannot be published.
@immutable
class PublishProblem {
  const PublishProblem(
    this.code, {
    this.target = ProblemTarget.none,
    this.id,
    this.field,
    this.name,
    this.details = const {},
  });

  factory PublishProblem.fromMap(Map<Object?, Object?> m) => PublishProblem(
    PublishProblemCode.fromWire(m['code']),
    target: switch (m['target']) {
      'restaurant' => ProblemTarget.restaurant,
      'category' => ProblemTarget.category,
      'item' => ProblemTarget.item,
      _ => ProblemTarget.none,
    },
    id: m['id'] as String?,
    field: m['field'] as String?,
    name: m['name'] as String?,
    details: m['details'] is Map
        ? Map<String, Object?>.from(m['details']! as Map)
        : const {},
  );

  final PublishProblemCode code;
  final ProblemTarget target;
  final String? id;
  final String? field;
  final String? name;
  final Map<String, Object?> details;

  /// Solved by the checkbox in the publish dialog, not by a fix elsewhere.
  bool get isPriceReview => code == PublishProblemCode.pricesNeedReview;

  static List<PublishProblem> listFrom(Object? value) => [
    if (value is List)
      for (final p in value)
        if (p is Map) PublishProblem.fromMap(p),
  ];
}

/// A category or item in the change summary.
@immutable
class ChangeRef {
  const ChangeRef(this.id, this.name);

  final String id;
  final String name;

  static List<ChangeRef> listFrom(Object? value) => [
    if (value is List)
      for (final r in value)
        if (r is Map)
          ChangeRef(r['id'] as String? ?? '', r['name'] as String? ?? ''),
  ];
}

@immutable
class ChangeLists {
  const ChangeLists({
    this.added = const [],
    this.changed = const [],
    this.removed = const [],
  });

  factory ChangeLists.fromMap(Object? m) => m is Map
      ? ChangeLists(
          added: ChangeRef.listFrom(m['added']),
          changed: ChangeRef.listFrom(m['changed']),
          removed: ChangeRef.listFrom(m['removed']),
        )
      : const ChangeLists();

  final List<ChangeRef> added;
  final List<ChangeRef> changed;
  final List<ChangeRef> removed;

  int get total => added.length + changed.length + removed.length;
}

/// FR-065: what publishing changes for customers.
@immutable
class ChangeSummary {
  const ChangeSummary({
    this.firstPublish = false,
    this.profileChanged = false,
    this.themeChanged = false,
    this.categories = const ChangeLists(),
    this.items = const ChangeLists(),
  });

  factory ChangeSummary.fromMap(Object? m) => m is Map
      ? ChangeSummary(
          firstPublish: m['firstPublish'] == true,
          profileChanged: m['profileChanged'] == true,
          themeChanged: m['themeChanged'] == true,
          categories: ChangeLists.fromMap(m['categories']),
          items: ChangeLists.fromMap(m['items']),
        )
      : const ChangeSummary();

  final bool firstPublish;
  final bool profileChanged;
  final bool themeChanged;
  final ChangeLists categories;
  final ChangeLists items;

  /// Publishing would change nothing customers see.
  bool get isEmpty =>
      !firstPublish &&
      !profileChanged &&
      !themeChanged &&
      categories.total == 0 &&
      items.total == 0;
}

/// Result of a dry run.
@immutable
class PublishCheck {
  const PublishCheck({
    required this.problems,
    required this.summary,
    this.currentVersion,
    this.pricesNeedReview = false,
  });

  factory PublishCheck.fromMap(Map<Object?, Object?> m) => PublishCheck(
    problems: PublishProblem.listFrom(m['problems']),
    summary: ChangeSummary.fromMap(m['summary']),
    currentVersion: m['currentVersion'] as int?,
    pricesNeedReview: m['pricesNeedReview'] == true,
  );

  final List<PublishProblem> problems;
  final ChangeSummary summary;
  final int? currentVersion;
  final bool pricesNeedReview;

  /// Problems that need a fix elsewhere (the price review is a checkbox).
  List<PublishProblem> get blocking =>
      problems.where((p) => !p.isPriceReview).toList();
}

/// Result of a publish or rollback.
@immutable
class PublishOutcome {
  const PublishOutcome({required this.version, required this.summary});

  factory PublishOutcome.fromMap(Map<Object?, Object?> m) => PublishOutcome(
    version: m['version']! as int,
    summary: ChangeSummary.fromMap(m['summary']),
  );

  final int version;
  final ChangeSummary summary;
}

/// The problems of a `publish-blocked` error, or null for any other error.
List<PublishProblem>? blockedProblemsOf(Object error) {
  if (error is! FirebaseFunctionsException) return null;
  if (appErrorCodeOfFunctions(error) != AppErrorCode.publishBlocked) {
    return null;
  }
  final d = error.details;
  return PublishProblem.listFrom(d is Map ? d['problems'] : null);
}
