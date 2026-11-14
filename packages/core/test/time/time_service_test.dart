import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-11-14 20:00 UTC.
  final fixed = DateTime.utc(2026, 11, 14, 20);
  final time = TimeService(clock: () => fixed);

  test('nowUtc uses the injected clock and is UTC', () {
    expect(time.nowUtc(), fixed);
    expect(time.nowUtc().isUtc, isTrue);
  });

  test('converts UTC to the restaurant zone', () {
    final kolkata = time.toZone(fixed, 'Asia/Kolkata'); // UTC+5:30
    expect([kolkata.year, kolkata.month, kolkata.day], [2026, 11, 15]);
    expect([kolkata.hour, kolkata.minute], [1, 30]);

    final kuwait = time.nowIn('Asia/Kuwait'); // UTC+3
    expect(kuwait.hour, 23);
  });

  test('converts restaurant wall-clock time back to UTC', () {
    final utc = time.fromZone('Asia/Dubai', 2026, 11, 15, 9); // UTC+4
    expect(utc, DateTime.utc(2026, 11, 15, 5));
    expect(utc.isUtc, isTrue);
  });

  test('handles daylight saving time', () {
    // New York: EDT (UTC-4) on 1 July, EST (UTC-5) on 1 December.
    expect(
      time.fromZone('America/New_York', 2026, 7, 1, 12),
      DateTime.utc(2026, 7, 1, 16),
    );
    expect(
      time.fromZone('America/New_York', 2026, 12, 1, 12),
      DateTime.utc(2026, 12, 1, 17),
    );
  });

  test('dayKey uses the restaurant day, not the UTC day', () {
    expect(time.dayKey(fixed, 'Asia/Kolkata'), '2026-11-15');
    expect(time.dayKey(fixed, 'UTC'), '2026-11-14');
  });

  test('startOfDayUtc returns local midnight as UTC', () {
    expect(
      time.startOfDayUtc(fixed, 'Asia/Kolkata'),
      DateTime.utc(2026, 11, 14, 18, 30),
    );
  });

  test('validates IANA zone names', () {
    expect(TimeService.isValidZone('Asia/Kolkata'), isTrue);
    expect(TimeService.isValidZone('Mars/Olympus'), isFalse);
  });
}
