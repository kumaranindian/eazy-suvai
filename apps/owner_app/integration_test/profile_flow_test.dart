// End-to-end onboarding and profile flow on the Firebase Emulator Suite
// (M03, AC-002, FR-092/093): a new verified owner lands in the setup
// wizard → profile basics autosave through the real security rules →
// finish → profile visibility and links → opening hours → currency →
// menu link change through `changeSlug` (reserved word refused). Also
// checks that the rules refuse a system field written by the client.
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
import 'package:owner_app/features/restaurant/presentation/menu_link_page.dart';
import 'package:owner_app/features/restaurant/presentation/profile_form.dart';
import 'package:owner_app/features/setup/presentation/setup_wizard_page.dart';
import 'package:owner_app/router/app_router.dart';

const _host = 'localhost';
const _project = AppEnv.demoProjectId;

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  String what = 'condition',
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (done()) return;
  }
  throw TestFailure('Timed out waiting for $what');
}

/// Waits until the restaurant document satisfies [done] (the write passed
/// the security rules and reached the emulator).
Future<Map<String, dynamic>> waitForDoc(
  WidgetTester tester,
  DocumentReference<Map<String, dynamic>> doc,
  bool Function(Map<String, dynamic> d) done, {
  required String what,
}) async {
  Map<String, dynamic> data = const {};
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    data =
        (await doc.get(const GetOptions(source: Source.server))).data() ??
        const {};
    if (done(data)) return data;
  }
  throw TestFailure('Timed out waiting for $what; document: $data');
}

/// Creates a verified owner with a restaurant, signed in, and returns its id.
Future<String> createVerifiedOwner() async {
  final email = 'profile${DateTime.now().millisecondsSinceEpoch}@example.com';
  await FirebaseAuth.instance.signOut();
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'Secret123!',
  );
  await regionalFunctions.httpsCallable('completeRegistration').call({
    'restaurantName': 'Profile Test Kitchen',
    'ownerName': 'Priya Raman',
    'mobile': '9876543210',
    'country': 'IN',
    'businessType': 'restaurant',
    'city': 'Chennai',
  });
  await cred.user!.sendEmailVerification();
  final codes = await http.get(
    Uri.parse(
      'http://$_host:${EmulatorPorts.auth}/emulator/v1/projects/$_project/oobCodes',
    ),
  );
  final code = ((jsonDecode(codes.body) as Map)['oobCodes'] as List)
      .cast<Map<String, dynamic>>()
      .lastWhere((c) => c['email'] == email)['oobCode'];
  await http.post(
    Uri.parse(
      'http://$_host:${EmulatorPorts.auth}/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key',
    ),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'oobCode': code}),
  );
  await FirebaseAuth.instance.currentUser!.reload();
  final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
  return token.claims!['restaurantId'] as String;
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

  testWidgets('wizard → profile → hours → currency → menu link (AC-002)', (
    tester,
  ) async {
    final rid = await createVerifiedOwner();
    final doc = FirebaseFirestore.instance.doc('restaurants/$rid');

    await tester.pumpWidget(const ProviderScope(child: OwnerApp()));
    final router = ProviderScope.containerOf(
      tester.element(find.byType(OwnerApp)),
    ).read(appRouterProvider);
    Future<void> go(String path) async {
      router.go(path);
      await tester.pumpAndSettle();
    }

    Future<void> enter(Key key, String text) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.enterText(find.byKey(key), text);
      await tester.pump();
    }

    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    // 1. A new owner lands in the wizard.
    await pumpUntil(
      tester,
      () => find.byKey(WizardKeys.next).evaluate().isNotEmpty,
      what: 'setup wizard',
    );
    await enter(ProfileKeys.description, 'Idli, dosa and filter coffee.');
    await enter(ProfileKeys.phone, '044 2345 6789');
    await tap(find.byKey(WizardKeys.next));
    var data = await waitForDoc(
      tester,
      doc,
      (d) => d['description'] == 'Idli, dosa and filter coffee.',
      what: 'wizard profile save',
    );
    expect(data['contact'], {'city': 'Chennai', 'phone': '+914423456789'});
    expect(data['draftUpdatedAt'], isA<Timestamp>());

    await tap(find.byKey(WizardKeys.next)); // skip the logo
    await tap(find.byKey(WizardKeys.toDashboard));
    await waitForDoc(
      tester,
      doc,
      (d) => d['setupCompletedAt'] is Timestamp,
      what: 'setup completed',
    );

    // 2. Profile: links and visibility autosave through the rules.
    await go(Routes.profile);
    await pumpUntil(
      tester,
      () => find.byKey(ProfileKeys.website).evaluate().isNotEmpty,
      what: 'profile page',
    );
    await enter(ProfileKeys.name, 'Profile Test Kitchen Café');
    await enter(ProfileKeys.website, 'profiletest.example');
    await enter(ProfileKeys.social(SocialNetwork.instagram), '@profiletest');
    // On the web the first tap after typing only moves focus out of the
    // text field, so drop the focus first. On a narrow window the section
    // is a collapsed panel; tapping its heading opens it (elsewhere the
    // heading does nothing).
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tap(find.text('Show on your menu'));
    await tap(find.byKey(ProfileKeys.visibility(VisibleField.phone)));
    data = await waitForDoc(
      tester,
      doc,
      (d) =>
          (d['visibility'] as Map?)?['phone'] == false &&
          (d['contact'] as Map?)?['website'] != null,
      what: 'profile autosave',
    );
    expect(data['name'], 'Profile Test Kitchen Café');
    expect((data['contact'] as Map)['website'], 'https://profiletest.example');
    expect((data['contact'] as Map)['social'], {
      'instagram': 'https://instagram.com/profiletest',
    });
    // onRestaurantUpdated keeps nameLower in sync.
    await waitForDoc(
      tester,
      doc,
      (d) => d['nameLower'] == 'profile test kitchen café',
      what: 'nameLower trigger',
    );

    // 3. Opening hours.
    await go(Routes.hours);
    await tap(find.text('Add opening hours'));
    data = await waitForDoc(
      tester,
      doc,
      (d) => d['openingHours'] is Map,
      what: 'opening hours',
    );
    expect((data['openingHours'] as Map)['mon'], '09:00-22:00');

    // 4. Currency (never published: no FR-103 dialog, no review flag).
    await go(Routes.regional);
    await tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>),
    );
    await tester.tap(find.text('UAE dirham (AED)').last);
    await tester.pumpAndSettle();
    data = await waitForDoc(
      tester,
      doc,
      (d) => d['currency'] == 'AED',
      what: 'currency',
    );
    expect(data['pricesNeedReview'], isFalse);

    // 5. Menu link through changeSlug.
    await go(Routes.menuLink);
    await enter(MenuLinkKeys.field, 'admin');
    await pumpUntil(
      tester,
      () => find
          .text('This link is reserved. Choose another one.')
          .evaluate()
          .isNotEmpty,
      what: 'reserved message',
    );
    final slug = 'profile-test-${DateTime.now().millisecondsSinceEpoch}';
    await enter(MenuLinkKeys.field, slug);
    await pumpUntil(
      tester,
      () => find.text('This link is available.').evaluate().isNotEmpty,
      what: 'availability check',
    );
    await tap(find.byKey(MenuLinkKeys.save));
    await tap(find.widgetWithText(FilledButton, 'Change link').last);
    await waitForDoc(
      tester,
      doc,
      (d) => d['slug'] == slug,
      what: 'slug change',
    );

    // 6. The rules refuse system fields from the client.
    await expectLater(
      doc.update({
        'planId': 'pro',
        'draftUpdatedAt': FieldValue.serverTimestamp(),
      }),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    await expectLater(
      doc.update({
        'slug': 'stolen',
        'draftUpdatedAt': FieldValue.serverTimestamp(),
      }),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });
}
