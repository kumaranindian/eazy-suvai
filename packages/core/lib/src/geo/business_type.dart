import '../l10n/generated/core_localizations.dart';

/// Business types offered at sign-up (FR-002, FR-011).
///
/// [name] is the stored value. Keep in sync with `BUSINESS_TYPES` in
/// `functions/src/auth/countries.ts`.
enum BusinessType {
  restaurant,
  cafe,
  bakery,
  cloudKitchen,
  sweetShop,
  juiceBar,
  foodTruck,
  bar,
  hotel,
  other;

  static BusinessType? fromName(String? value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }

  String label(CoreLocalizations l10n) => switch (this) {
    BusinessType.restaurant => l10n.businessTypeRestaurant,
    BusinessType.cafe => l10n.businessTypeCafe,
    BusinessType.bakery => l10n.businessTypeBakery,
    BusinessType.cloudKitchen => l10n.businessTypeCloudKitchen,
    BusinessType.sweetShop => l10n.businessTypeSweetShop,
    BusinessType.juiceBar => l10n.businessTypeJuiceBar,
    BusinessType.foodTruck => l10n.businessTypeFoodTruck,
    BusinessType.bar => l10n.businessTypeBar,
    BusinessType.hotel => l10n.businessTypeHotel,
    BusinessType.other => l10n.businessTypeOther,
  };
}
