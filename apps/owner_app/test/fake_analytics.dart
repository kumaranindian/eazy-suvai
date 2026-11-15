import 'dart:async';

import 'package:owner_app/features/analytics/data/analytics_repository.dart';
import 'package:owner_app/features/analytics/domain/analytics.dart';

/// In-memory `analyticsDaily` documents (M09).
class FakeAnalyticsRepository implements AnalyticsRepository {
  FakeAnalyticsRepository([List<AnalyticsDay> days = const []])
    : days = [...days];

  final List<AnalyticsDay> days;
  final ranges = <(String, String)>[];

  @override
  Stream<List<AnalyticsDay>> watchRange(
    String restaurantId,
    String start,
    String end,
  ) {
    ranges.add((start, end));
    return Stream.value([
      for (final d in days)
        if (d.date.compareTo(start) >= 0 && d.date.compareTo(end) <= 0) d,
    ]);
  }
}

/// "Today" in the tests: 15 Nov 2026, 10:00 in India.
final analyticsTestNow = DateTime.utc(2026, 11, 15, 4, 30);
