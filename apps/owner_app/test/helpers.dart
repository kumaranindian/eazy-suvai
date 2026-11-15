import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owner_app/app.dart';
import 'package:owner_app/features/account/data/account_notices.dart';
import 'package:owner_app/features/account/data/account_repository.dart';
import 'package:owner_app/features/analytics/data/analytics_repository.dart';
import 'package:owner_app/features/auth/data/registration_repository.dart';
import 'package:owner_app/features/plan/data/plan_repository.dart';
import 'package:owner_app/features/menu/data/menu_repository.dart';
import 'package:owner_app/features/publishing/data/publishing_repository.dart';
import 'package:owner_app/features/publishing/presentation/menu_html_view.dart';
import 'package:owner_app/features/qr/application/qr_image.dart';
import 'package:owner_app/features/qr/application/qr_providers.dart';
import 'package:owner_app/features/qr/presentation/qr_pdf_preview.dart';
import 'package:owner_app/features/restaurant/data/restaurant_repository.dart';
import 'package:owner_app/features/theme/data/theme_repository.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_analytics.dart';
import 'fake_menu.dart';
import 'fake_plan.dart';
import 'fake_publishing.dart';
import 'fake_theme.dart';

/// Stands in for the `completeRegistration` callable: sets owner claims on
/// the fake auth user, like the real function does.
class FakeRegistrationRepository implements RegistrationRepository {
  FakeRegistrationRepository(this.auth);

  final FakeAuthRepository auth;
  final List<RegistrationDetails?> calls = [];
  Object? nextError;

  @override
  Future<RegistrationResult> complete(RegistrationDetails? details) async {
    calls.add(details);
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    final user = auth.current;
    if (user == null) {
      throw FirebaseFunctionsException(
        message: 'x',
        code: 'unauthenticated',
        details: {'code': 'unauthenticated'},
      );
    }
    final existing = user.claims['restaurantId'];
    if (existing == null && details == null) {
      throw FirebaseFunctionsException(
        message: 'x',
        code: 'failed-precondition',
        details: {'code': 'registration-incomplete'},
      );
    }
    user.claims = {'role': 'owner', 'restaurantId': existing ?? 'rest_1'};
    return RegistrationResult(
      restaurantId: user.claims['restaurantId']! as String,
      slug: 'spice-garden',
      qrCode: 'ABCDEFGH',
      created: existing == null,
    );
  }
}

/// `restaurants/rest_1` as M01 creates it, with setup finished (so the
/// dashboard does not open the wizard). Override fields per test.
Map<String, dynamic> restaurantData([Map<String, dynamic> extra = const {}]) =>
    {
      'name': 'Spice Garden',
      'nameLower': 'spice garden',
      'ownerUid': 'u1',
      'businessType': 'restaurant',
      'country': 'IN',
      'currency': 'INR',
      'timezone': 'Asia/Kolkata',
      'contact': {'city': 'Chennai'},
      'slug': 'spice-garden',
      'qrCode': 'ABCDEFGH',
      'status': 'active',
      'planId': 'free',
      'counts': {'categories': 0, 'items': 0},
      'publishedVersion': null,
      'pricesNeedReview': false,
      'themeId': null,
      'setupCompletedAt': DateTime.utc(2026, 11, 14),
      ...extra,
    };

FirebaseFunctionsException slugError(String code) => FirebaseFunctionsException(
  message: code,
  code: code == 'slug-taken' ? 'already-exists' : 'invalid-argument',
  details: {'code': code},
);

/// In-memory `restaurants/rest_1` with the security rules' behaviour that
/// matters to the UI: draft writes merge whole top-level fields.
class FakeRestaurantRepository implements RestaurantRepository {
  FakeRestaurantRepository([Map<String, dynamic>? data])
    : data = data ?? restaurantData();

  Map<String, dynamic> data;
  final updates = <Map<String, Object?>>[];
  final slugChecks = <String>[];
  final slugChanges = <String>[];
  int setupCompletions = 0;
  int qrDownloads = 0;

  @override
  Future<void> countQrDownload(String restaurantId) async => qrDownloads++;

  /// Thrown once by the next [updateDraft].
  Object? nextError;

  /// Slugs other restaurants hold (current or old).
  Set<String> taken = {'other-place'};

  final _changes = StreamController<Restaurant?>.broadcast();

  Restaurant get current => Restaurant.fromMap('rest_1', data);

  void emit([Map<String, dynamic> extra = const {}]) {
    data = {...data, ...extra};
    _changes.add(current);
  }

  @override
  Stream<Restaurant?> watch(String restaurantId) async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> updateDraft(
    String restaurantId,
    Map<String, Object?> fields,
  ) async {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    updates.add(fields);
    emit({...fields, 'draftUpdatedAt': DateTime.utc(2026, 11, 14, 6)});
  }

  @override
  Future<void> completeSetup(String restaurantId) async {
    setupCompletions++;
    emit({'setupCompletedAt': DateTime.utc(2026, 11, 14, 7)});
  }

  void _check(String slug) {
    final local = SlugRules.check(slug);
    if (local != null) throw slugError(local.wire);
    if (taken.contains(slug)) throw slugError('slug-taken');
  }

  @override
  Future<SlugChange> checkSlug(String restaurantId, String slug) async {
    slugChecks.add(slug);
    _check(slug);
    return SlugChange(
      slug: slug,
      previousSlug: data['slug'] as String,
      changed: false,
    );
  }

  @override
  Future<SlugChange> changeSlug(String restaurantId, String slug) async {
    _check(slug);
    slugChanges.add(slug);
    final previous = data['slug'] as String;
    emit({'slug': slug});
    return SlugChange(slug: slug, previousSlug: previous, changed: true);
  }
}

/// A verified owner with claims.
FakeUser verifiedOwner({String email = 'owner@example.com'}) => FakeUser(
  uid: 'u1',
  email: email,
  password: 'Secret123!',
  emailVerified: true,
  claims: {'role': 'owner', 'restaurantId': 'rest_1'},
);

class TestApp {
  TestApp(
    this.tester,
    this.auth,
    this.registration,
    this.restaurant,
    this.resolver,
    this.menu,
    this.themes,
    this.publishing,
  );

  final WidgetTester tester;
  final FakeAuthRepository auth;
  final FakeRegistrationRepository registration;
  final FakeRestaurantRepository restaurant;
  final FakeStorageImageResolver resolver;
  final FakeMenuRepository menu;
  final FakeThemeRepository themes;
  final FakePublishingRepository publishing;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(OwnerApp)));

  GoRouter get router => container.read(appRouterProvider);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> go(String path) async {
    router.go(path);
    await tester.pumpAndSettle();
  }

  Future<void> enter(Key key, String text) async {
    final f = find.byKey(key);
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  Future<void> enterLabelled(String label, String text) async {
    final f = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> choose(Key dropdown, String item) async {
    await tap(find.byKey(dropdown));
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  /// Disposes the tree so page timers (resend countdown) are cancelled.
  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 61));
  }
}

Future<void> setWidth(
  WidgetTester tester,
  double width, {
  double height = 900,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

Future<TestApp> pumpOwnerApp(
  WidgetTester tester, {
  double width = 360,
  double height = 900,
  List<FakeUser> users = const [],
  FakeUser? signedIn,
  FakeRestaurantRepository? restaurant,
  FakeMenuRepository? menu,
  FakeThemeRepository? themes,
  FakePublishingRepository? publishing,
  QrArtifactBuilder? qrBuilder,
  FakeAnalyticsRepository? analytics,
  FakePlanRepository? plans,
  String accountStatus = 'active',
  PlatformNotice notice = const PlatformNotice(),
  AccountRepository? account,
  List<Override> overrides = const [],
}) async {
  await setWidth(tester, width, height: height);
  final auth = FakeAuthRepository(users: [...users, ?signedIn]);
  if (signedIn != null) auth.current = signedIn;
  final registration = FakeRegistrationRepository(auth);
  final restaurants = restaurant ?? FakeRestaurantRepository();
  final resolver = FakeStorageImageResolver();
  final menus = menu ?? FakeMenuRepository();
  final themeRepo = themes ?? FakeThemeRepository();
  final publishingRepo = publishing ?? FakePublishingRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        registrationRepositoryProvider.overrideWithValue(registration),
        restaurantRepositoryProvider.overrideWithValue(restaurants),
        storageImageResolverProvider.overrideWithValue(resolver),
        menuRepositoryProvider.overrideWithValue(menus),
        themeRepositoryProvider.overrideWithValue(themeRepo),
        publishingRepositoryProvider.overrideWithValue(publishingRepo),
        menuHtmlViewBuilderProvider.overrideWithValue(fakeMenuHtmlView),
        // QR codes render in the test zone (no isolate); PDFs are not
        // rasterised (M08). qr_share_test.dart fakes sharing and the logo.
        qrArtifactBuilderProvider.overrideWithValue(
          qrBuilder ?? (job) async => buildQrArtifact(job),
        ),
        // Analytics (M09): fixed "today", in-memory daily documents.
        analyticsRepositoryProvider.overrideWithValue(
          analytics ?? FakeAnalyticsRepository(),
        ),
        analyticsClockProvider.overrideWithValue(() => analyticsTestNow),
        // Plans (M10): in memory, with a fixed "now" for banners.
        planRepositoryProvider.overrideWithValue(
          plans ?? FakePlanRepository(restaurants: restaurants),
        ),
        planClockProvider.overrideWithValue(() => planTestNow),
        // M11: account status and the announcement.
        accountStatusProvider.overrideWith(
          (ref) => Stream.value(accountStatus),
        ),
        platformNoticeProvider.overrideWith((ref) => Stream.value(notice)),
        accountRepositoryProvider.overrideWithValue(
          account ?? FakeAccountRepository(),
        ),
        qrPdfViewBuilderProvider.overrideWithValue(
          (pdf) => Text('PDF ${pdf.length} bytes'),
        ),
        // Google Fonts are not fetched in tests.
        menuFontResolverProvider.overrideWithValue(
          const PlainMenuFontResolver(),
        ),
        ...overrides,
      ],
      child: const OwnerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(
    tester,
    auth,
    registration,
    restaurants,
    resolver,
    menus,
    themeRepo,
    publishingRepo,
  );
}

/// Export and deletion callables (M12), in memory.
class FakeAccountRepository implements AccountRepository {
  final exports = <String>[];
  final deletions = <(String, String)>[];
  Object? nextError;

  @override
  Future<MenuExportFiles> exportMenu(String restaurantId) async {
    exports.add(restaurantId);
    return const MenuExportFiles(
      fileBase: 'spice-garden-menu-2026-11-15',
      json: '{"items":[]}',
      csv: 'category,item',
    );
  }

  @override
  Future<DateTime?> requestDeletion(
    String restaurantId,
    String confirmName,
  ) async {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    deletions.add((restaurantId, confirmName));
    return DateTime.utc(2027, 2, 13);
  }
}
