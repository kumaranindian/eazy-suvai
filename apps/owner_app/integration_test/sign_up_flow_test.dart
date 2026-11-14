// End-to-end owner account flow on the Firebase Emulator Suite (AC-001):
// sign up → "Check your email" → sign-in refused before verification →
// verify via the emulator link → sign in → read own restaurant through the
// security rules → sign out → password reset email.
//
// Run with: bash tool/integration.sh   (starts the emulators and Chrome)
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:owner_app/app.dart';

const _host = 'localhost';
const _project = AppEnv.demoProjectId;

Future<List<Map<String, dynamic>>> _oobCodes() async {
  final res = await http.get(
    Uri.parse(
      'http://$_host:${EmulatorPorts.auth}/emulator/v1/projects/$_project/oobCodes',
    ),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return (body['oobCodes'] as List).cast<Map<String, dynamic>>();
}

Future<void> _applyOobCode(String code) async {
  final res = await http.post(
    Uri.parse(
      'http://$_host:${EmulatorPorts.auth}/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key',
    ),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'oobCode': code}),
  );
  expect(res.statusCode, 200, reason: res.body);
}

/// Pumps until [finder] matches or [timeout] passes (network calls).
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> enter(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TimeService.ensureInitialized();
    await initFirebase(
      AppEnv.parse(envName: 'dev', useEmulators: true),
      optionsFor: (_) => throw StateError('emulators only'),
    );
  });

  testWidgets('sign up → verify → sign in → sign out → reset (AC-001)', (
    tester,
  ) async {
    final email = 'owner${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'Secret123!';
    await FirebaseAuth.instance.signOut();

    await tester.pumpWidget(const ProviderScope(child: OwnerApp()));
    await pumpUntil(tester, find.byKey(const ValueKey('signIn.submit')));

    // Sign up.
    await tap(tester, find.text('Create an account'));
    await pumpUntil(tester, find.byKey(const ValueKey('signUp.submit')));
    await enter(
      tester,
      find.byKey(const ValueKey('signUp.restaurantName')),
      'Spice Garden',
    );
    await tap(tester, find.byKey(const ValueKey('signUp.businessType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurant').last);
    await tester.pumpAndSettle();
    await enter(tester, find.byKey(const ValueKey('signUp.city')), 'Chennai');
    await enter(
      tester,
      find.byKey(const ValueKey('signUp.ownerName')),
      'Priya Raman',
    );
    await enter(
      tester,
      find.widgetWithText(TextFormField, 'Mobile number'),
      '9876543210',
    );
    await enter(tester, find.byKey(const ValueKey('signUp.email')), email);
    await enter(
      tester,
      find.byKey(const ValueKey('signUp.password')),
      password,
    );
    await tap(tester, find.byKey(const ValueKey('signUp.submit')));

    await pumpUntil(tester, find.text('Check your email'));
    expect(FirebaseAuth.instance.currentUser, isNull, reason: 'signed out');

    // Sign-in before verification is refused (FR-091).
    await tap(tester, find.byKey(const ValueKey('verify.back')));
    await pumpUntil(tester, find.byKey(const ValueKey('signIn.submit')));
    await enter(tester, find.byKey(const ValueKey('signIn.email')), email);
    await enter(
      tester,
      find.byKey(const ValueKey('signIn.password')),
      password,
    );
    await tap(tester, find.byKey(const ValueKey('signIn.submit')));
    await pumpUntil(
      tester,
      find.textContaining('Verify your email address before'),
    );
    expect(FirebaseAuth.instance.currentUser, isNull);

    // Open the verification link (emulator).
    final verify = (await _oobCodes()).lastWhere(
      (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL',
    );
    await _applyOobCode(verify['oobCode'] as String);

    // Sign in: claims are present and the dashboard opens.
    await tap(tester, find.byKey(const ValueKey('verify.back')));
    await pumpUntil(tester, find.byKey(const ValueKey('signIn.submit')));
    await enter(tester, find.byKey(const ValueKey('signIn.email')), email);
    await enter(
      tester,
      find.byKey(const ValueKey('signIn.password')),
      password,
    );
    await tap(tester, find.byKey(const ValueKey('signIn.submit')));
    // M03: a new owner first lands in the setup wizard; skip it.
    await pumpUntil(tester, find.byKey(const ValueKey('wizard.skip')));
    await tap(tester, find.byKey(const ValueKey('wizard.skip')));
    await pumpUntil(tester, find.widgetWithText(AppBar, 'Home'));

    final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult();
    expect(token.claims!['role'], 'owner');
    final rid = token.claims!['restaurantId'] as String;

    // The rules let the verified owner read their own restaurant.
    final restaurant = await FirebaseFirestore.instance
        .doc('restaurants/$rid')
        .get();
    expect(restaurant.get('planId'), 'free');
    expect(restaurant.get('status'), 'active');
    expect(restaurant.get('currency'), 'INR');
    expect(restaurant.get('slug') as String, startsWith('spice-garden'));
    expect(restaurant.get('qrCode') as String, hasLength(8));
    final profile = await FirebaseFirestore.instance
        .doc('users/${FirebaseAuth.instance.currentUser!.uid}')
        .get();
    expect(profile.get('mobile'), '+919876543210');

    // Sign out.
    await tap(tester, find.byTooltip('Sign out'));
    await pumpUntil(tester, find.byKey(const ValueKey('signIn.submit')));
    expect(FirebaseAuth.instance.currentUser, isNull);

    // Password reset email (FR-006).
    await enter(tester, find.byKey(const ValueKey('signIn.email')), email);
    await tap(tester, find.text('Forgot password?'));
    await pumpUntil(tester, find.byKey(const ValueKey('forgot.submit')));
    await tap(tester, find.byKey(const ValueKey('forgot.submit')));
    await pumpUntil(tester, find.textContaining("we've sent a reset link"));
    final codes = await _oobCodes();
    expect(
      codes.any(
        (c) => c['email'] == email && c['requestType'] == 'PASSWORD_RESET',
      ),
      isTrue,
    );
  });
}
