import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One `plans/{id}` document (M10, FR-076, FR-078).
class PlanInfo {
  const PlanInfo({
    required this.id,
    required this.name,
    required this.isFree,
    required this.features,
    this.sort = 0,
    this.billing = const [],
    this.prices = const {},
  });

  factory PlanInfo.fromMap(String id, Map<String, dynamic> data) {
    final prices = <String, Map<String, int>>{};
    final raw = data['prices'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.key is String && e.value is Map) {
          prices[e.key as String] = {
            for (final p in (e.value as Map).entries)
              if (p.key is String && p.value is num)
                p.key as String: (p.value as num).toInt(),
          };
        }
      }
    }
    return PlanInfo(
      id: id,
      name: data['name'] as String? ?? id,
      isFree: data['isFree'] == true,
      features: PlanFeatures.fromMap(data['limits'], planId: id),
      sort: (data['sort'] as num?)?.toInt() ?? 0,
      billing: [
        for (final b in (data['billing'] as List?) ?? const [])
          if (b is String) b,
      ],
      prices: prices,
    );
  }

  final String id;
  final String name;
  final bool isFree;
  final PlanFeatures features;
  final int sort;

  /// `monthly`, `annual`.
  final List<String> billing;

  /// `{currency: {monthly: minor, annual: minor}}` (open decision: prices).
  final Map<String, Map<String, int>> prices;
}

/// The plans as shown when no documents are seeded yet (FRD §4.11).
const fallbackPlans = [
  PlanInfo(id: 'free', name: 'Free', isFree: true, features: PlanFeatures.free),
  PlanInfo(
    id: 'pro',
    name: 'Pro',
    isFree: false,
    sort: 1,
    features: PlanFeatures.pro,
    billing: ['monthly', 'annual'],
  ),
];

/// Plans and the owner's subscription callables (M10).
abstract class PlanRepository {
  Stream<List<PlanInfo>> watchPlans();

  /// `requestUpgrade` (FR-106).
  Future<void> requestUpgrade(
    String restaurantId,
    String planId,
    String billing,
  );

  /// `setHiddenOverLimit` (FR-101): swap, or downgrade to Free.
  Future<void> setHidden(
    String restaurantId, {
    List<String> hideItemIds = const [],
    List<String> showItemIds = const [],
    List<String> hideCategoryIds = const [],
    List<String> showCategoryIds = const [],
    bool downgrade = false,
  });
}

class FirebasePlanRepository implements PlanRepository {
  FirebasePlanRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<PlanInfo>> watchPlans() =>
      _db.collection('plans').snapshots().map((s) {
        final list = [
          for (final d in s.docs)
            if (d.data()['active'] != false) PlanInfo.fromMap(d.id, d.data()),
        ]..sort((a, b) => a.sort.compareTo(b.sort));
        return list.isEmpty ? fallbackPlans : list;
      });

  @override
  Future<void> requestUpgrade(
    String restaurantId,
    String planId,
    String billing,
  ) => _functions.httpsCallable('requestUpgrade').call<Object?>({
    'restaurantId': restaurantId,
    'planId': planId,
    'billing': billing,
  });

  @override
  Future<void> setHidden(
    String restaurantId, {
    List<String> hideItemIds = const [],
    List<String> showItemIds = const [],
    List<String> hideCategoryIds = const [],
    List<String> showCategoryIds = const [],
    bool downgrade = false,
  }) => _functions.httpsCallable('setHiddenOverLimit').call<Object?>({
    'restaurantId': restaurantId,
    'hideItemIds': hideItemIds,
    'showItemIds': showItemIds,
    'hideCategoryIds': hideCategoryIds,
    'showCategoryIds': showCategoryIds,
    'downgrade': downgrade,
  });
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) =>
      FirebasePlanRepository(FirebaseFirestore.instance, regionalFunctions),
);

final plansProvider = StreamProvider<List<PlanInfo>>(
  (ref) => ref.watch(planRepositoryProvider).watchPlans(),
);

/// The clock for banners and expiry text. Tests override it.
final planClockProvider = Provider<Clock>((ref) => DateTime.now);

/// "Unlimited" is stored as a high number (M10): show it as unlimited.
bool isUnlimited(int? max) => max == null || max >= 10000;
