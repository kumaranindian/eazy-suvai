import 'package:flutter/foundation.dart';

import '../l10n/generated/core_localizations.dart';

/// Days of the week, in the order the editor shows them. [key] is the
/// field name in `openingHours`.
enum Weekday {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  String get key => name;

  /// ISO weekday number (Monday = 1), as `DateTime.weekday`.
  int get iso => index + 1;

  static Weekday fromIso(int weekday) => Weekday.values[weekday - 1];

  String label(CoreLocalizations l10n) => switch (this) {
    Weekday.mon => l10n.weekdayMon,
    Weekday.tue => l10n.weekdayTue,
    Weekday.wed => l10n.weekdayWed,
    Weekday.thu => l10n.weekdayThu,
    Weekday.fri => l10n.weekdayFri,
    Weekday.sat => l10n.weekdaySat,
    Weekday.sun => l10n.weekdaySun,
  };
}

/// A wall-clock time in minutes after midnight (0–1439), in the
/// restaurant's time zone.
typedef Minutes = int;

/// Formats minutes as `HH:mm`.
String formatHhMm(Minutes minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Parses `HH:mm` (00:00–23:59), or returns null.
Minutes? parseHhMm(String text) {
  final match = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$').firstMatch(text);
  if (match == null) return null;
  return int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

/// One opening period. A [close] at or before [open] runs past midnight
/// (`18:00–02:00`); `00:00` as a close means midnight, and `00:00–00:00` is
/// open all day.
@immutable
class TimeSlot {
  const TimeSlot(this.open, this.close);

  final Minutes open;
  final Minutes close;

  /// Close in minutes after this day's midnight: past 1440 when the slot
  /// runs into the next day.
  int get end => close <= open ? close + 1440 : close;

  bool get isAllDay => open == 0 && close == 0;

  /// Runs past midnight into the next day (closing at midnight does not).
  bool get isOvernight => close != 0 && close < open;

  /// `HH:mm-HH:mm`, the stored form.
  String get wire => '${formatHhMm(open)}-${formatHhMm(close)}';

  static TimeSlot? parse(String text) {
    final parts = text.split('-');
    if (parts.length != 2) return null;
    final open = parseHhMm(parts[0]);
    final close = parseHhMm(parts[1]);
    if (open == null || close == null) return null;
    return TimeSlot(open, close);
  }

  TimeSlot copyWith({Minutes? open, Minutes? close}) =>
      TimeSlot(open ?? this.open, close ?? this.close);

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.open == open && other.close == close;

  @override
  int get hashCode => Object.hash(open, close);

  @override
  String toString() => wire;
}

/// Why a day's slots are not valid.
enum HoursIssue {
  /// A slot opens and closes at the same time (other than all day).
  sameTime,

  /// Slots are not in order through the day, or overlap.
  overlap,

  /// Only the last slot of a day may run past midnight.
  overnightNotLast,

  /// More than [OpeningHours.maxSlots] slots.
  tooManySlots;

  String message(CoreLocalizations l10n) => switch (this) {
    HoursIssue.sameTime => l10n.hoursErrorSameTime,
    HoursIssue.overlap => l10n.hoursErrorOverlap,
    HoursIssue.overnightNotLast => l10n.hoursErrorOvernightNotLast,
    HoursIssue.tooManySlots => l10n.hoursErrorTooMany(OpeningHours.maxSlots),
  };
}

/// Opening hours (FR-011): per weekday up to [maxSlots] slots, or closed
/// (no slots).
///
/// Stored as `openingHours: {mon: "07:00-11:00,18:00-23:30", tue: "", …}`:
/// one string per day so the security rules can check a whole week with a
/// single regex (see `firestore.rules`). An empty string is closed.
@immutable
class OpeningHours {
  OpeningHours(Map<Weekday, List<TimeSlot>> days)
    : days = Map.unmodifiable({
        for (final d in Weekday.values)
          d: List<TimeSlot>.unmodifiable(days[d] ?? const []),
      });

  /// Every day open 09:00–22:00: the starting point when an owner first
  /// adds hours.
  factory OpeningHours.template() => OpeningHours({
    for (final d in Weekday.values) d: const [TimeSlot(9 * 60, 22 * 60)],
  });

  static const maxSlots = 3;

  /// Slots per day; an empty list is closed.
  final Map<Weekday, List<TimeSlot>> days;

  List<TimeSlot> operator [](Weekday day) => days[day]!;

  bool isClosed(Weekday day) => days[day]!.isEmpty;

  /// Reads the stored map, or null if [value] is not a map. Unreadable
  /// slots are dropped.
  static OpeningHours? fromWire(Object? value) {
    if (value is! Map) return null;
    return OpeningHours({
      for (final d in Weekday.values)
        d: [
          for (final part
              in (value[d.key] is String ? value[d.key] as String : '').split(
                ',',
              ))
            if (part.isNotEmpty) ?TimeSlot.parse(part),
        ],
    });
  }

  Map<String, String> toWire() => {
    for (final d in Weekday.values)
      d.key: days[d]!.map((s) => s.wire).join(','),
  };

  OpeningHours withDay(Weekday day, List<TimeSlot> slots) =>
      OpeningHours({...days, day: slots});

  /// Problems per day; empty when everything is valid.
  Map<Weekday, HoursIssue> validate() => {
    for (final d in Weekday.values)
      if (validateDay(days[d]!) case final issue?) d: issue,
  };

  bool get isValid => validate().isEmpty;

  /// Checks one day's slots: at most [maxSlots], each with different open
  /// and close times (or all day), in order without overlaps, and only the
  /// last one running past midnight.
  static HoursIssue? validateDay(List<TimeSlot> slots) {
    if (slots.length > maxSlots) return HoursIssue.tooManySlots;
    for (final s in slots) {
      if (s.open == s.close && !s.isAllDay) return HoursIssue.sameTime;
    }
    if (slots.any((s) => s.isAllDay) && slots.length > 1) {
      return HoursIssue.overlap;
    }
    for (var i = 0; i < slots.length - 1; i++) {
      if (slots[i].isOvernight) return HoursIssue.overnightNotLast;
      if (slots[i].end > slots[i + 1].open) return HoursIssue.overlap;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is OpeningHours &&
      Weekday.values.every((d) => listEquals(days[d], other.days[d]));

  @override
  int get hashCode => Object.hashAll([
    for (final d in Weekday.values) Object.hashAll(days[d]!),
  ]);
}
