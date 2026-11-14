import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Returns the current instant. Replace it in tests.
typedef Clock = DateTime Function();

/// Converts between stored UTC instants and a restaurant's IANA time zone.
///
/// Rule: everything is stored in UTC. Values are shown in the restaurant's
/// time zone (for example `Asia/Kolkata`), never the device's.
class TimeService {
  TimeService({Clock? clock}) : _clock = clock ?? DateTime.now {
    ensureInitialized();
  }

  final Clock _clock;
  static bool _initialized = false;

  /// Loads the IANA time zone database once.
  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  /// Whether [zone] is a valid IANA zone name.
  static bool isValidZone(String zone) {
    ensureInitialized();
    try {
      tz.getLocation(zone);
      return true;
    } on tz.LocationNotFoundException {
      return false;
    }
  }

  /// Current instant in UTC.
  DateTime nowUtc() => _clock().toUtc();

  /// Current wall-clock time in [zone].
  tz.TZDateTime nowIn(String zone) => toZone(nowUtc(), zone);

  /// Converts a UTC (or any absolute) instant to wall-clock time in [zone].
  tz.TZDateTime toZone(DateTime instant, String zone) =>
      tz.TZDateTime.from(instant.toUtc(), tz.getLocation(zone));

  /// Converts wall-clock fields in [zone] to the UTC instant.
  DateTime fromZone(
    String zone,
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
  ]) => tz.TZDateTime(
    tz.getLocation(zone),
    year,
    month,
    day,
    hour,
    minute,
  ).toUtc();

  /// The calendar day of [instant] in [zone] as `yyyy-MM-dd`. Used for the
  /// `analyticsDaily/{yyyy-MM-dd}` document id (architecture §4.2).
  String dayKey(DateTime instant, String zone) {
    final local = toZone(instant, zone);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)}';
  }

  /// Start of the calendar day containing [instant] in [zone], as UTC.
  DateTime startOfDayUtc(DateTime instant, String zone) {
    final local = toZone(instant, zone);
    return fromZone(zone, local.year, local.month, local.day);
  }
}
