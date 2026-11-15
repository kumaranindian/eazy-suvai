/// Analytics data for the owner screen (M09, FR-071 to FR-075).
///
/// `restaurants/{rid}/analyticsDaily/{yyyy-MM-dd}` (written by
/// `collectEvent`): `views`, `qrVisits`, `categoryTaps {cid: n}`,
/// `itemOpens {iid: n}`. The day is in the restaurant's time zone, so ranges
/// are computed on day keys, never on device-local dates.
library;

/// One `analyticsDaily` document.
class AnalyticsDay {
  const AnalyticsDay({
    required this.date,
    this.views = 0,
    this.qrVisits = 0,
    this.categoryTaps = const {},
    this.itemOpens = const {},
  });

  factory AnalyticsDay.fromMap(String id, Map<String, dynamic> data) {
    int n(Object? v) => v is num ? v.toInt() : 0;
    Map<String, int> counts(Object? v) => v is Map
        ? {
            for (final e in v.entries)
              if (e.key is String) e.key as String: n(e.value),
          }
        : const {};
    return AnalyticsDay(
      date: id,
      views: n(data['views']),
      qrVisits: n(data['qrVisits']),
      categoryTaps: counts(data['categoryTaps']),
      itemOpens: counts(data['itemOpens']),
    );
  }

  /// `yyyy-MM-dd` in the restaurant's time zone.
  final String date;
  final int views;
  final int qrVisits;
  final Map<String, int> categoryTaps;
  final Map<String, int> itemOpens;
}

/// The FR-074 range choices.
enum AnalyticsRangeKind { last7, last30, custom }

/// A closed range of day keys.
class AnalyticsRange {
  const AnalyticsRange(this.kind, this.start, this.end);

  final AnalyticsRangeKind kind;

  /// First and last day, `yyyy-MM-dd`, inclusive.
  final String start;
  final String end;

  int get days => daysBetween(start, end) + 1;

  @override
  bool operator ==(Object other) =>
      other is AnalyticsRange &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}

DateTime _parse(String key) => DateTime.utc(
  int.parse(key.substring(0, 4)),
  int.parse(key.substring(5, 7)),
  int.parse(key.substring(8, 10)),
);

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [key] moved by [days] (calendar days; no time zone involved).
String addDays(String key, int days) =>
    _key(_parse(key).add(Duration(days: days)));

/// Whole days from [a] to [b].
int daysBetween(String a, String b) => _parse(b).difference(_parse(a)).inDays;

/// A `DateTime` (UTC midnight) for a key, for date pickers and labels.
DateTime dateOfKey(String key) => _parse(key);

/// The key of a picked calendar date (only year, month and day are used).
String keyOfDate(DateTime d) => _key(DateTime.utc(d.year, d.month, d.day));

/// Every key from [start] to [end], inclusive.
List<String> dayKeys(String start, String end) => [
  for (var i = 0; i <= daysBetween(start, end); i++) addDays(start, i),
];

/// "Last 7 days" and "last 30 days" end today (in the restaurant's zone).
AnalyticsRange presetRange(
  AnalyticsRangeKind kind,
  String today,
) => switch (kind) {
  AnalyticsRangeKind.last7 => AnalyticsRange(kind, addDays(today, -6), today),
  AnalyticsRangeKind.last30 => AnalyticsRange(kind, addDays(today, -29), today),
  AnalyticsRangeKind.custom => throw ArgumentError('custom has no preset'),
};

/// The earliest day a plan with [historyDays] may look at (FR-074).
String earliestAllowed(String today, int historyDays) =>
    addDays(today, -(historyDays - 1));

/// Whether [range] fits the plan's history.
bool rangeAllowed(AnalyticsRange range, String today, int historyDays) =>
    range.start.compareTo(earliestAllowed(today, historyDays)) >= 0;

/// One point of the daily chart.
class DailyPoint {
  const DailyPoint(this.date, this.views, this.qrVisits);
  final String date;
  final int views;
  final int qrVisits;
}

/// Totals for one calendar month in the range.
class MonthTotal {
  const MonthTotal(this.month, this.views, this.qrVisits);

  /// `yyyy-MM`.
  final String month;
  final int views;
  final int qrVisits;
}

/// A ranked category or item.
class Ranked {
  const Ranked(this.id, this.count);
  final String id;
  final int count;
}

/// Everything the screen shows for a range (FR-071).
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.range,
    required this.views,
    required this.qrVisits,
    required this.categoryTaps,
    required this.itemOpens,
    required this.series,
    required this.topCategories,
    required this.topItems,
    required this.months,
  });

  final AnalyticsRange range;
  final int views;
  final int qrVisits;
  final int categoryTaps;
  final int itemOpens;

  /// One point per day of the range, zeros included.
  final List<DailyPoint> series;
  final List<Ranked> topCategories;
  final List<Ranked> topItems;
  final List<MonthTotal> months;

  /// Share of views that came from the QR code, 0–1 (0 without views).
  double get qrShare => views == 0 ? 0 : qrVisits / views;

  bool get isEmpty =>
      views == 0 && qrVisits == 0 && categoryTaps == 0 && itemOpens == 0;
}

List<Ranked> _rank(Map<String, int> counts, int limit) {
  final list =
      [
        for (final e in counts.entries)
          if (e.value > 0) Ranked(e.key, e.value),
      ]..sort(
        (a, b) => b.count.compareTo(a.count) != 0
            ? b.count.compareTo(a.count)
            : a.id.compareTo(b.id),
      );
  return list.take(limit).toList();
}

/// Merges the daily documents of [range] into totals, a gap-free daily
/// series, the top 5 categories and items, and monthly totals.
AnalyticsSummary summarize(
  AnalyticsRange range,
  Iterable<AnalyticsDay> days, {
  int top = 5,
}) {
  final byDate = {
    for (final d in days)
      if (d.date.compareTo(range.start) >= 0 &&
          d.date.compareTo(range.end) <= 0)
        d.date: d,
  };
  var views = 0, qr = 0, taps = 0, opens = 0;
  final cats = <String, int>{};
  final items = <String, int>{};
  final months = <String, (int, int)>{};
  final series = <DailyPoint>[];
  for (final key in dayKeys(range.start, range.end)) {
    final d = byDate[key];
    final v = d?.views ?? 0;
    final q = d?.qrVisits ?? 0;
    series.add(DailyPoint(key, v, q));
    views += v;
    qr += q;
    final m = key.substring(0, 7);
    final cur = months[m] ?? (0, 0);
    months[m] = (cur.$1 + v, cur.$2 + q);
    if (d == null) continue;
    for (final e in d.categoryTaps.entries) {
      cats[e.key] = (cats[e.key] ?? 0) + e.value;
      taps += e.value;
    }
    for (final e in d.itemOpens.entries) {
      items[e.key] = (items[e.key] ?? 0) + e.value;
      opens += e.value;
    }
  }
  return AnalyticsSummary(
    range: range,
    views: views,
    qrVisits: qr,
    categoryTaps: taps,
    itemOpens: opens,
    series: series,
    topCategories: _rank(cats, top),
    topItems: _rank(items, top),
    months: [
      for (final e in months.entries) MonthTotal(e.key, e.value.$1, e.value.$2),
    ],
  );
}

/// History a plan may view (FR-074; FRD §4.11: Free 7 days, Pro 365).
/// M10 replaces this with `plans/{planId}.limits.analyticsDays`.
int defaultAnalyticsDays(String planId) => planId == 'pro' ? 365 : 7;
