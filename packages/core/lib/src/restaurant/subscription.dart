import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

DateTime? _time(Object? v) =>
    v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// The plan flags copied to `restaurants/{rid}.planFeatures` by Functions
/// (M10). Missing values mean the Free plan (FRD §4.11).
@immutable
class PlanFeatures {
  const PlanFeatures({
    this.maxItems = 50,
    this.maxCategories = 10,
    this.premiumThemes = false,
    this.analyticsDays = 7,
    this.qrLogo = false,
    this.removeBranding = false,
  });

  factory PlanFeatures.fromMap(Object? map, {String planId = 'free'}) {
    final fallback = planId == 'pro' ? pro : free;
    if (map is! Map) return fallback;
    int? limit(Object? v, int? d) =>
        v == null ? null : (v is num && v >= 0 ? v.toInt() : d);
    return PlanFeatures(
      maxItems: map.containsKey('maxItems')
          ? limit(map['maxItems'], fallback.maxItems)
          : fallback.maxItems,
      maxCategories: map.containsKey('maxCategories')
          ? limit(map['maxCategories'], fallback.maxCategories)
          : fallback.maxCategories,
      premiumThemes: map['premiumThemes'] is bool
          ? map['premiumThemes'] as bool
          : fallback.premiumThemes,
      analyticsDays: map['analyticsDays'] is num
          ? (map['analyticsDays'] as num).toInt()
          : fallback.analyticsDays,
      qrLogo: map['qrLogo'] is bool ? map['qrLogo'] as bool : fallback.qrLogo,
      removeBranding: map['removeBranding'] is bool
          ? map['removeBranding'] as bool
          : fallback.removeBranding,
    );
  }

  static const free = PlanFeatures();
  static const pro = PlanFeatures(
    maxItems: 500,
    maxCategories: 10000,
    premiumThemes: true,
    analyticsDays: 365,
    qrLogo: true,
    removeBranding: true,
  );

  /// Null = unlimited.
  final int? maxItems;
  final int? maxCategories;
  final bool premiumThemes;
  final int analyticsDays;
  final bool qrLogo;
  final bool removeBranding;
}

enum SubscriptionStatus {
  free,
  active,
  grace;

  static SubscriptionStatus fromWire(Object? v) =>
      SubscriptionStatus.values.asNameMap()[v] ?? SubscriptionStatus.free;
}

/// `restaurants/{rid}.subscription` (M10, FR-080, FR-100).
@immutable
class Subscription {
  const Subscription({
    this.status = SubscriptionStatus.free,
    this.planId = 'free',
    this.billing,
    this.startAt,
    this.expiresAt,
    this.graceEndsAt,
  });

  factory Subscription.fromMap(Object? map, {String planId = 'free'}) {
    if (map is! Map) return Subscription(planId: planId);
    return Subscription(
      status: SubscriptionStatus.fromWire(map['status']),
      planId: map['planId'] as String? ?? planId,
      billing: map['billing'] as String?,
      startAt: _time(map['startAt']),
      expiresAt: _time(map['expiresAt']),
      graceEndsAt: _time(map['graceEndsAt']),
    );
  }

  final SubscriptionStatus status;
  final String planId;

  /// `monthly` or `annual`.
  final String? billing;
  final DateTime? startAt;
  final DateTime? expiresAt;
  final DateTime? graceEndsAt;

  bool get isPaid =>
      status == SubscriptionStatus.active || status == SubscriptionStatus.grace;

  /// Whole days until [at] from [now], rounded up, never negative.
  static int daysUntil(DateTime at, DateTime now) {
    final ms = at.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / Duration.millisecondsPerDay).ceil();
  }

  /// FR-100 dashboard reminder: within 14 days of expiry.
  bool expiresSoon(DateTime now) =>
      status == SubscriptionStatus.active &&
      expiresAt != null &&
      daysUntil(expiresAt!, now) <= 14;
}

/// `restaurants/{rid}.planNotice`: what the last plan change did (M10).
@immutable
class PlanNotice {
  const PlanNotice({
    required this.kind,
    this.hiddenItems = 0,
    this.hiddenCategories = 0,
    this.themeReverted = false,
    this.restored = 0,
    this.at,
  });

  static PlanNotice? fromMap(Object? map) {
    if (map is! Map || map['kind'] is! String) return null;
    int n(Object? v) => v is num ? v.toInt() : 0;
    return PlanNotice(
      kind: map['kind'] as String,
      hiddenItems: n(map['hiddenItems']),
      hiddenCategories: n(map['hiddenCategories']),
      themeReverted: map['themeReverted'] == true,
      restored: n(map['restored']),
      at: _time(map['at']),
    );
  }

  /// `limitsApplied` (downgrade) or `restored` (upgrade).
  final String kind;
  final int hiddenItems;
  final int hiddenCategories;
  final bool themeReverted;
  final int restored;
  final DateTime? at;

  bool get limitsApplied => kind == 'limitsApplied';
  bool get restoredContent => kind == 'restored';
}
