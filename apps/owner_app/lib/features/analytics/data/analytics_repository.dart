import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../restaurant/data/restaurant_repository.dart';
import '../domain/analytics.dart';

/// Reads `restaurants/{rid}/analyticsDaily` (M09). Readable only by the
/// owner and admins (rules); written only by `collectEvent`.
abstract class AnalyticsRepository {
  /// The daily documents from [start] to [end] (day keys, inclusive).
  Stream<List<AnalyticsDay>> watchRange(
    String restaurantId,
    String start,
    String end,
  );
}

class FirestoreAnalyticsRepository implements AnalyticsRepository {
  FirestoreAnalyticsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AnalyticsDay>> watchRange(
    String restaurantId,
    String start,
    String end,
  ) => _db
      .collection('restaurants/$restaurantId/analyticsDaily')
      .orderBy(FieldPath.documentId)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
      .where(FieldPath.documentId, isLessThanOrEqualTo: end)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) AnalyticsDay.fromMap(d.id, d.data())],
      );
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => FirestoreAnalyticsRepository(FirebaseFirestore.instance),
);

/// Today's key in the restaurant's time zone. Tests override the clock.
final analyticsClockProvider = Provider<Clock>((ref) => DateTime.now);

final analyticsTodayProvider = Provider.autoDispose<String?>((ref) {
  final zone = ref.watch(
    currentRestaurantProvider.select((r) => r.value?.timezone),
  );
  if (zone == null) return null;
  final clock = ref.watch(analyticsClockProvider);
  return TimeService(clock: clock).dayKey(clock(), zone);
});

/// Days of history the restaurant's plan allows (FR-074).
final analyticsHistoryDaysProvider = Provider.autoDispose<int>((ref) {
  // M10: limits.analyticsDays, copied to the restaurant as planFeatures.
  return ref.watch(
    currentRestaurantProvider.select(
      (r) =>
          r.value?.planFeatures.analyticsDays ?? defaultAnalyticsDays('free'),
    ),
  );
});

/// The chosen range; null means "last 7 days".
class AnalyticsRangeChoice extends Notifier<AnalyticsRange?> {
  @override
  AnalyticsRange? build() => null;

  // ignore: use_setters_to_change_properties
  void set(AnalyticsRange range) => state = range;
}

final analyticsRangeChoiceProvider =
    NotifierProvider<AnalyticsRangeChoice, AnalyticsRange?>(
      AnalyticsRangeChoice.new,
    );

/// The range in effect.
final analyticsRangeProvider = Provider.autoDispose<AnalyticsRange?>((ref) {
  final today = ref.watch(analyticsTodayProvider);
  if (today == null) return null;
  return ref.watch(analyticsRangeChoiceProvider) ??
      presetRange(AnalyticsRangeKind.last7, today);
});

/// The summary of the range in effect.
final analyticsSummaryProvider = StreamProvider.autoDispose<AnalyticsSummary>((
  ref,
) {
  final range = ref.watch(analyticsRangeProvider);
  final rid = ref.watch(currentRestaurantIdProvider);
  if (range == null || rid == null) return const Stream.empty();
  return ref
      .watch(analyticsRepositoryProvider)
      .watchRange(rid, range.start, range.end)
      .map((days) => summarize(range, days));
});
