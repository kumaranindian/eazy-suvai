import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owner_app/app.dart';
import 'package:owner_app/features/auth/data/registration_repository.dart';
import 'package:owner_app/router/app_router.dart';

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

/// A verified owner with claims.
FakeUser verifiedOwner({String email = 'owner@example.com'}) => FakeUser(
  uid: 'u1',
  email: email,
  password: 'Secret123!',
  emailVerified: true,
  claims: {'role': 'owner', 'restaurantId': 'rest_1'},
);

class TestApp {
  TestApp(this.tester, this.auth, this.registration);

  final WidgetTester tester;
  final FakeAuthRepository auth;
  final FakeRegistrationRepository registration;

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
  List<FakeUser> users = const [],
  FakeUser? signedIn,
}) async {
  await setWidth(tester, width);
  final auth = FakeAuthRepository(users: [...users, ?signedIn]);
  if (signedIn != null) auth.current = signedIn;
  final registration = FakeRegistrationRepository(auth);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        registrationRepositoryProvider.overrideWithValue(registration),
      ],
      child: const OwnerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(tester, auth, registration);
}
