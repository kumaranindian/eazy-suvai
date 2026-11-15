import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart';

import '../geo/business_type.dart';
import '../l10n/generated/core_localizations.dart';
import '../media/image_object.dart';
import '../theme/menu_theme.dart';
import 'opening_hours.dart';

/// Social networks a profile can link to (FR-011).
enum SocialNetwork {
  instagram,
  facebook,
  x,
  youtube,
  googleMaps;

  /// Field name in `contact.social`.
  String get key => name;

  String label(CoreLocalizations l10n) => switch (this) {
    SocialNetwork.instagram => l10n.socialInstagram,
    SocialNetwork.facebook => l10n.socialFacebook,
    SocialNetwork.x => l10n.socialX,
    SocialNetwork.youtube => l10n.socialYoutube,
    SocialNetwork.googleMaps => l10n.socialGoogleMaps,
  };
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

/// `contact` on `restaurants/{rid}`. Empty values are left out when stored.
@immutable
class ContactInfo {
  const ContactInfo({
    this.phone,
    this.email,
    this.address,
    this.city,
    this.postalCode,
    this.website,
    this.social = const {},
  });

  factory ContactInfo.fromMap(Object? value) {
    if (value is! Map) return const ContactInfo();
    final social = value['social'];
    return ContactInfo(
      phone: _str(value['phone']),
      email: _str(value['email']),
      address: _str(value['address']),
      city: _str(value['city']),
      postalCode: _str(value['postalCode']),
      website: _str(value['website']),
      social: {
        if (social is Map)
          for (final n in SocialNetwork.values)
            if (_str(social[n.key]) case final url?) n: url,
      },
    );
  }

  /// E.164, for example `+914423456789`.
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? postalCode;

  /// `https://` URL.
  final String? website;

  /// `https://` URLs by network.
  final Map<SocialNetwork, String> social;

  Map<String, Object> toMap() {
    final links = {
      for (final e in social.entries)
        if (e.value.trim().isNotEmpty) e.key.key: e.value.trim(),
    };
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      if (clean(phone) case final v?) 'phone': v,
      if (clean(email) case final v?) 'email': v,
      if (clean(address) case final v?) 'address': v,
      if (clean(city) case final v?) 'city': v,
      if (clean(postalCode) case final v?) 'postalCode': v,
      if (clean(website) case final v?) 'website': v,
      if (links.isNotEmpty) 'social': links,
    };
  }

  ContactInfo copyWith({
    ValueGetter<String?>? phone,
    ValueGetter<String?>? email,
    ValueGetter<String?>? address,
    ValueGetter<String?>? city,
    ValueGetter<String?>? postalCode,
    ValueGetter<String?>? website,
    Map<SocialNetwork, String>? social,
  }) => ContactInfo(
    phone: phone != null ? phone() : this.phone,
    email: email != null ? email() : this.email,
    address: address != null ? address() : this.address,
    city: city != null ? city() : this.city,
    postalCode: postalCode != null ? postalCode() : this.postalCode,
    website: website != null ? website() : this.website,
    social: social ?? this.social,
  );

  @override
  bool operator ==(Object other) =>
      other is ContactInfo && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode =>
      Object.hashAll(toMap().entries.map((e) => '${e.key}=${e.value}'));
}

/// Public detail groups an owner can show or hide (FR-013).
enum VisibleField {
  phone,
  email,
  address,
  hours,
  social;

  String get key => name;
}

/// `visibility` on `restaurants/{rid}`. A missing entry means **shown**:
/// the public menu (M07) omits a group only when its flag is `false`.
@immutable
class PublicVisibility {
  const PublicVisibility([this.hidden = const {}]);

  factory PublicVisibility.fromMap(Object? value) => PublicVisibility({
    if (value is Map)
      for (final f in VisibleField.values)
        if (value[f.key] == false) f,
  });

  final Set<VisibleField> hidden;

  bool isShown(VisibleField field) => !hidden.contains(field);

  PublicVisibility withField(VisibleField field, {required bool shown}) =>
      PublicVisibility(
        shown ? ({...hidden}..remove(field)) : {...hidden, field},
      );

  /// All five flags, so the stored value is explicit.
  Map<String, bool> toMap() => {
    for (final f in VisibleField.values) f.key: isShown(f),
  };

  @override
  bool operator ==(Object other) =>
      other is PublicVisibility && setEquals(other.hidden, hidden);

  @override
  int get hashCode => Object.hashAllUnordered(hidden);
}

/// The draft profile fields the owner app writes to `restaurants/{rid}`
/// (the security rules' whitelist, M03).
abstract final class RestaurantFields {
  static const name = 'name';
  static const businessType = 'businessType';
  static const description = 'description';
  static const logo = 'logo';
  static const cover = 'cover';
  static const contact = 'contact';
  static const openingHours = 'openingHours';
  static const visibility = 'visibility';
  static const currency = 'currency';
  static const timezone = 'timezone';
  static const themeId = 'themeId';
  static const themeSettings = 'themeSettings';
  static const draftUpdatedAt = 'draftUpdatedAt';
  static const setupCompletedAt = 'setupCompletedAt';

  /// FR-011 limits (also in `firestore.rules`).
  static const nameMax = 80;
  static const descriptionMax = 500;
  static const addressMax = 200;
  static const cityMax = 60;
}

/// `restaurants/{rid}` as the owner app sees it (architecture §4.2).
///
/// Profile and theme fields are the **draft**; they go live on publish
/// (FR-012, M06). System fields (`slug`, `qrCode`, `status`, `planId`,
/// `counts`, `publishedVersion`, `pricesNeedReview`) are written only by
/// Cloud Functions.
@immutable
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.businessType,
    this.description = '',
    this.logo,
    this.cover,
    this.contact = const ContactInfo(),
    this.openingHours,
    this.visibility = const PublicVisibility(),
    required this.country,
    required this.currency,
    required this.timezone,
    this.slug = '',
    this.qrCode = '',
    this.status = 'active',
    this.planId = 'free',
    this.publishedVersion,
    this.pricesNeedReview = false,
    this.categoryCount = 0,
    this.itemCount = 0,
    this.themeId,
    this.themeSettings = const ThemeSettings(),
    this.draftUpdatedAt,
    this.setupCompletedAt,
  });

  factory Restaurant.fromMap(String id, Map<String, dynamic> data) {
    final counts = data['counts'];
    int count(String key) =>
        counts is Map && counts[key] is int ? counts[key] as int : 0;
    DateTime? time(Object? v) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    return Restaurant(
      id: id,
      name: data['name'] as String? ?? '',
      businessType: BusinessType.fromName(data['businessType'] as String?),
      description: data['description'] as String? ?? '',
      logo: ImageObject.fromMap(data['logo']),
      cover: ImageObject.fromMap(data['cover']),
      contact: ContactInfo.fromMap(data['contact']),
      openingHours: OpeningHours.fromWire(data['openingHours']),
      visibility: PublicVisibility.fromMap(data['visibility']),
      country: data['country'] as String? ?? '',
      currency: data['currency'] as String? ?? '',
      timezone: data['timezone'] as String? ?? 'UTC',
      slug: data['slug'] as String? ?? '',
      qrCode: data['qrCode'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      planId: data['planId'] as String? ?? 'free',
      publishedVersion: data['publishedVersion'] as int?,
      pricesNeedReview: data['pricesNeedReview'] == true,
      categoryCount: count('categories'),
      itemCount: count('items'),
      themeId: data['themeId'] as String?,
      themeSettings: ThemeSettings.fromMap(data['themeSettings']),
      draftUpdatedAt: time(data['draftUpdatedAt']),
      setupCompletedAt: time(data['setupCompletedAt']),
    );
  }

  final String id;
  final String name;
  final BusinessType? businessType;
  final String description;
  final ImageObject? logo;
  final ImageObject? cover;
  final ContactInfo contact;

  /// Null until the owner adds hours.
  final OpeningHours? openingHours;
  final PublicVisibility visibility;

  /// ISO alpha-2, set at sign-up; not editable by the owner.
  final String country;
  final String currency;
  final String timezone;
  final String slug;
  final String qrCode;
  final String status;
  final String planId;

  /// Null until the first publish (M06).
  final int? publishedVersion;

  /// Set by `onRestaurantUpdated` when the currency changed after a publish
  /// (FR-103); M06 clears it.
  final bool pricesNeedReview;
  final int categoryCount;
  final int itemCount;

  /// The chosen predefined theme (`themes/{id}`, M05); null until chosen.
  final String? themeId;

  /// The owner's overrides of the theme (M05).
  final ThemeSettings themeSettings;
  final DateTime? draftUpdatedAt;

  /// When the first-run setup wizard was finished or skipped.
  final DateTime? setupCompletedAt;

  bool get isPublished => publishedVersion != null;

  /// Copy with draft edits applied, for live previews.
  Restaurant copyWith({
    String? name,
    ValueGetter<BusinessType?>? businessType,
    String? description,
    ContactInfo? contact,
    ValueGetter<OpeningHours?>? openingHours,
    PublicVisibility? visibility,
    String? currency,
    String? timezone,
    String? slug,
    ValueGetter<String?>? themeId,
    ThemeSettings? themeSettings,
  }) => Restaurant(
    id: id,
    name: name ?? this.name,
    businessType: businessType != null ? businessType() : this.businessType,
    description: description ?? this.description,
    logo: logo,
    cover: cover,
    contact: contact ?? this.contact,
    openingHours: openingHours != null ? openingHours() : this.openingHours,
    visibility: visibility ?? this.visibility,
    country: country,
    currency: currency ?? this.currency,
    timezone: timezone ?? this.timezone,
    slug: slug ?? this.slug,
    qrCode: qrCode,
    status: status,
    planId: planId,
    publishedVersion: publishedVersion,
    pricesNeedReview: pricesNeedReview,
    categoryCount: categoryCount,
    itemCount: itemCount,
    themeId: themeId != null ? themeId() : this.themeId,
    themeSettings: themeSettings ?? this.themeSettings,
    draftUpdatedAt: draftUpdatedAt,
    setupCompletedAt: setupCompletedAt,
  );
}

/// Steps on the dashboard's setup checklist (FRD §5.1, steps 4–8).
enum SetupStep { profile, logo, categories, items, theme, publish }

/// The setup checklist, derived from the restaurant document.
@immutable
class SetupChecklist {
  const SetupChecklist(this.done);

  factory SetupChecklist.of(Restaurant r) => SetupChecklist({
    if (isProfileComplete(r)) SetupStep.profile,
    if (r.logo?.isReady ?? false) SetupStep.logo,
    if (r.categoryCount > 0) SetupStep.categories,
    if (r.itemCount > 0) SetupStep.items,
    if (r.themeId != null) SetupStep.theme,
    if (r.isPublished) SetupStep.publish,
  });

  final Set<SetupStep> done;

  int get doneCount => done.length;
  int get total => SetupStep.values.length;
  bool get isComplete => doneCount == total;
  bool isDone(SetupStep step) => done.contains(step);

  /// The first step still to do, or null.
  SetupStep? get next {
    for (final s in SetupStep.values) {
      if (!done.contains(s)) return s;
    }
    return null;
  }

  /// "Complete your profile": name, business type and description, a way
  /// to reach the restaurant (phone or email) and where it is (address or
  /// city).
  static bool isProfileComplete(Restaurant r) =>
      r.name.trim().isNotEmpty &&
      r.businessType != null &&
      r.description.trim().isNotEmpty &&
      (r.contact.phone != null || r.contact.email != null) &&
      (r.contact.address != null || r.contact.city != null);
}

/// Localized currency names for the currencies in FRD §6.2. Unknown codes
/// (added later through `config/platform`) fall back to the code.
extension CurrencyNames on CoreLocalizations {
  String currencyName(String code) => switch (code) {
    'INR' => currencyINR,
    'AED' => currencyAED,
    'KWD' => currencyKWD,
    'SAR' => currencySAR,
    'QAR' => currencyQAR,
    'BHD' => currencyBHD,
    'OMR' => currencyOMR,
    'USD' => currencyUSD,
    _ => code,
  };
}
