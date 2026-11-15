import 'package:core/core.dart';
import 'package:owner_app/features/plan/data/plan_repository.dart';

import 'helpers.dart';

/// Plans and the subscription callables (M10), in memory.
class FakePlanRepository implements PlanRepository {
  FakePlanRepository({this.restaurants, List<PlanInfo>? plans})
    : plans = plans ?? fallbackPlans;

  final FakeRestaurantRepository? restaurants;
  final List<PlanInfo> plans;
  final requests = <(String, String)>[];
  final hides = <Map<String, Object>>[];
  Object? nextError;

  @override
  Stream<List<PlanInfo>> watchPlans() => Stream.value(plans);

  @override
  Future<void> requestUpgrade(
    String restaurantId,
    String planId,
    String billing,
  ) async {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    requests.add((planId, billing));
    restaurants?.emit({'pendingUpgradeRequestId': 'req_1'});
  }

  @override
  Future<void> setHidden(
    String restaurantId, {
    List<String> hideItemIds = const [],
    List<String> showItemIds = const [],
    List<String> hideCategoryIds = const [],
    List<String> showCategoryIds = const [],
    bool downgrade = false,
  }) async {
    hides.add({
      'hideItemIds': hideItemIds,
      'showItemIds': showItemIds,
      'hideCategoryIds': hideCategoryIds,
      'showCategoryIds': showCategoryIds,
      'downgrade': downgrade,
    });
    if (downgrade) {
      restaurants?.emit({
        'planId': 'free',
        'subscription': {'status': 'free', 'planId': 'free'},
        'planFeatures': {'maxItems': 50, 'maxCategories': 10},
      });
    }
  }
}

/// "Now" for plan banners: 15 Nov 2026.
final planTestNow = DateTime.utc(2026, 11, 15, 6);

/// A Pro subscription ending on [expiresAt] (or in grace until [graceEndsAt]).
Map<String, dynamic> proData({
  DateTime? expiresAt,
  DateTime? graceEndsAt,
  Map<String, dynamic> extra = const {},
}) => {
  'planId': 'pro',
  'planFeatures': {
    'maxItems': 500,
    'maxCategories': 10000,
    'premiumThemes': true,
    'analyticsDays': 365,
    'qrLogo': true,
    'removeBranding': true,
  },
  'subscription': {
    'status': graceEndsAt == null ? 'active' : 'grace',
    'planId': 'pro',
    'billing': 'annual',
    'expiresAt': expiresAt ?? DateTime.utc(2027, 11, 15),
    'graceEndsAt': ?graceEndsAt,
  },
  ...extra,
};

PlanFeatures get proFeatures => PlanFeatures.pro;
