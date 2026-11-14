// End-to-end menu management on the Firebase Emulator Suite (M04): the
// three-pane layout at 1280 px drives the real callables, security rules and
// triggers.
//
// add category (createCategory) → add item with an INR price (createItem,
// priceMinor) → sold out on the row (direct update through the rules →
// onItemWrite → live/availability, AC-007) → edit the price → second
// category, bulk move (moveItems) → reorder with "Move up" (batched
// sequence writes) → delete the empty category → restore it from Recently
// deleted (restoreDeleted) → counts kept by the functions. Also checks that
// the rules refuse a client-created item.
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
import 'package:owner_app/features/menu/presentation/category_dialogs.dart';
import 'package:owner_app/features/menu/presentation/item_editor.dart';
import 'package:owner_app/features/menu/presentation/menu_actions.dart';
import 'package:owner_app/router/app_router.dart';

const _host = 'localhost';
const _project = AppEnv.demoProjectId;
const _firestore =
    'http://$_host:${EmulatorPorts.firestore}/v1/projects/$_project/databases/(default)/documents';

/// Admin access to the Firestore emulator's REST API (bypasses the rules).
const _admin = {
  'content-type': 'application/json',
  'authorization': 'Bearer owner',
};

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
  // Say what is on screen, to tell a validation message from a server error.
  final texts = [
    for (final e in find.byType(Text).evaluate())
      if ((e.widget as Text).data case final String t) t,
  ];
  final fields = [
    for (final e in find.byType(EditableText).evaluate())
      (e.widget as EditableText).controller.text,
  ];
  throw TestFailure(
    'Timed out waiting for $what; on screen: $texts; fields: $fields',
  );
}

/// Polls [read] from the emulator until [done].
Future<T> waitFor<T>(
  WidgetTester tester,
  Future<T> Function() read,
  bool Function(T v) done, {
  required String what,
}) async {
  late T value;
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    value = await read();
    if (done(value)) return value;
  }
  throw TestFailure('Timed out waiting for $what; last value: $value');
}

/// Seeds the platform dietary labels and tags (scripts/seed-platform.mjs).
Future<void> seedPlatformLabels() async {
  Future<void> put(
    String collection,
    String id,
    String name,
    String icon,
    int sort,
  ) async {
    await http.patch(
      Uri.parse('$_firestore/$collection/$id'),
      headers: _admin,
      body: jsonEncode({
        'fields': {
          'name': {'stringValue': name},
          'icon': {'stringValue': icon},
          'sort': {'integerValue': '$sort'},
          'retired': {'booleanValue': false},
        },
      }),
    );
  }

  await put('dietaryLabels', 'vegetarian', 'Vegetarian', 'veg', 10);
  await put('dietaryLabels', 'non-vegetarian', 'Non-vegetarian', 'nonVeg', 20);
  await put('dietaryLabels', 'vegan', 'Vegan', 'vegan', 30);
  await put('dietaryLabels', 'contains-egg', 'Contains egg', 'egg', 40);
  await put('itemTags', 'spicy', 'Spicy', 'spicy', 10);
  await put('itemTags', 'new', 'New', 'new', 40);
}

/// `restaurants/{rid}/live/availability` as the public menu (M07) reads it.
Future<Map<String, dynamic>> liveAvailability(String rid) async {
  final res = await http.get(
    Uri.parse('$_firestore/restaurants/$rid/live/availability'),
    headers: _admin,
  );
  if (res.statusCode != 200) return const {};
  final fields = (jsonDecode(res.body) as Map)['fields'] as Map?;
  final items =
      ((fields?['items'] as Map?)?['mapValue'] as Map?)?['fields'] as Map? ??
      const {};
  return {
    for (final e in items.entries)
      e.key as String: (e.value as Map)['booleanValue'],
  };
}

/// Creates a verified owner with a restaurant (setup finished), signed in.
Future<String> createVerifiedOwner() async {
  final email = 'menu${DateTime.now().millisecondsSinceEpoch}@example.com';
  await FirebaseAuth.instance.signOut();
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'Secret123!',
  );
  await regionalFunctions.httpsCallable('completeRegistration').call({
    'restaurantName': 'Menu Test Kitchen',
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
  final rid = token.claims!['restaurantId'] as String;
  // Skip the first-run wizard (M03).
  await FirebaseFirestore.instance.doc('restaurants/$rid').update({
    'setupCompletedAt': FieldValue.serverTimestamp(),
  });
  return rid;
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

  testWidgets('categories, items, availability, move, reorder, delete and '
      'restore (AC-003, AC-004, AC-007, AC-028)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    await seedPlatformLabels();
    final rid = await createVerifiedOwner();
    final db = FirebaseFirestore.instance;
    final root = db.doc('restaurants/$rid');
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docs(
      String collection,
    ) async =>
        (await db
                .collection('restaurants/$rid/$collection')
                .get(const GetOptions(source: Source.server)))
            .docs;
    Future<Map<String, dynamic>> rootData() async =>
        (await root.get(const GetOptions(source: Source.server))).data()!;

    await tester.pumpWidget(const ProviderScope(child: OwnerApp()));
    final router = ProviderScope.containerOf(
      tester.element(find.byType(OwnerApp)),
    ).read(appRouterProvider);
    await pumpUntil(
      tester,
      () => router.routerDelegate.currentConfiguration.uri.path == '/',
      what: 'dashboard',
    );
    router.go(Routes.menu);
    await tester.pumpAndSettle();

    Future<void> enter(Key key, String text) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.enterText(find.byKey(key), text);
      await tester.pump();
      // On the web the first tap after typing only moves focus.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    Future<void> tapAndWait(Finder f, bool Function() done, String what) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await pumpUntil(tester, done, what: what);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(MenuKeys.editorPane), findsOneWidget);

    // 1. Category through createCategory.
    await tap(find.byKey(MenuKeys.addCategory));
    await enter(CategoryDialogKeys.name, 'Starters');
    await tapAndWait(
      find.byKey(CategoryDialogKeys.save),
      () => find.byType(AlertDialog).evaluate().isEmpty,
      'category dialog closes',
    );
    final starters = (await waitFor(
      tester,
      () => docs('categories'),
      (d) => d.length == 1,
      what: 'category created',
    )).single;
    expect(starters.data(), containsPair('name', 'Starters'));
    expect(starters.data()['sequence'], 1000);

    // 2. Item through createItem: ₹249.50 → 24950 paise.
    await tap(find.byKey(MenuKeys.addItem));
    await enter(ItemEditorKeys.name, 'Paneer tikka');
    await enter(ItemEditorKeys.price, '249.5');
    await pumpUntil(
      tester,
      () => find
          .byKey(ItemEditorKeys.dietary('vegetarian'))
          .evaluate()
          .isNotEmpty,
      what: 'dietary labels',
    );
    await tap(find.byKey(ItemEditorKeys.dietary('vegetarian')));
    await tap(find.byKey(ItemEditorKeys.tag('spicy')));
    await tapAndWait(
      find.byKey(ItemEditorKeys.save),
      () => find.text('Edit item').evaluate().isNotEmpty,
      'editor switches to the new item',
    );
    final item = (await waitFor(
      tester,
      () => docs('items'),
      (d) => d.length == 1,
      what: 'item created',
    )).single;
    expect(item.data(), containsPair('priceMinor', 24950));
    expect(item.data(), containsPair('categoryId', starters.id));
    expect(item.data(), containsPair('dietaryLabelId', 'vegetarian'));
    expect(item.data()['tagIds'], ['spicy']);
    expect(item.data()['available'], isTrue);
    await waitFor(
      tester,
      rootData,
      (d) => (d['counts'] as Map)['items'] == 1,
      what: 'counts.items',
    );
    // The photo picker is now enabled (the document exists, M02).
    expect(find.byType(ImagePickerField), findsOneWidget);

    // 3. Sold out on the row: a direct update through the rules, and the
    //    trigger writes the live overlay (FR-095, AC-007).
    await tap(find.byKey(MenuKeys.itemAvailable(item.id)));
    await waitFor(
      tester,
      () => liveAvailability(rid),
      (m) => m[item.id] == false,
      what: 'live/availability',
    );
    expect(
      (await item.reference.get(
        const GetOptions(source: Source.server),
      )).get('available'),
      isFalse,
    );

    // 4. Edit the price in the pane (whitelisted update with updatedAt).
    await enter(ItemEditorKeys.price, '259');
    await tap(find.byKey(ItemEditorKeys.save));
    await waitFor(
      tester,
      () async => (await item.reference.get(
        const GetOptions(source: Source.server),
      )).data()!,
      (d) => d['priceMinor'] == 25900,
      what: 'price saved',
    );

    // 5. Second category, then bulk move the item there (moveItems).
    await tap(find.byKey(MenuKeys.addCategory));
    await enter(CategoryDialogKeys.name, 'Mains');
    await tapAndWait(
      find.byKey(CategoryDialogKeys.save),
      () => find.byType(AlertDialog).evaluate().isEmpty,
      'second category',
    );
    final mains = (await waitFor(
      tester,
      () => docs('categories'),
      (d) => d.length == 2,
      what: 'second category created',
    )).firstWhere((d) => d.id != starters.id);
    await tap(find.byKey(MenuKeys.category(starters.id)));
    await tap(find.byKey(MenuKeys.itemSelect(item.id)));
    await tap(find.byKey(MenuKeys.bulkMove));
    await tap(find.byKey(ValueKey('pickCategory.${mains.id}')));
    await waitFor(
      tester,
      () async => (await item.reference.get(
        const GetOptions(source: Source.server),
      )).data()!,
      (d) => d['categoryId'] == mains.id,
      what: 'item moved',
    );

    // 6. Reorder with the keyboard alternative: Mains first.
    await tap(find.byKey(MenuKeys.categoryMenu(mains.id)));
    await tap(find.text('Move up'));
    await waitFor(
      tester,
      () async => (await mains.reference.get(
        const GetOptions(source: Source.server),
      )).data()!,
      (d) => (d['sequence'] as int) < 1000,
      what: 'category reordered',
    );

    // 7. Delete the now empty Starters, then restore it (FR-018, FR-098).
    await tap(find.byKey(MenuKeys.categoryMenu(starters.id)));
    await tap(find.text('Delete'));
    await tap(find.widgetWithText(FilledButton, 'Delete'));
    await waitFor(
      tester,
      rootData,
      (d) => (d['counts'] as Map)['categories'] == 1,
      what: 'category deleted',
    );
    await tap(find.byKey(MenuKeys.recentlyDeleted));
    await pumpUntil(
      tester,
      () => find.byKey(MenuKeys.restore(starters.id)).evaluate().isNotEmpty,
      what: 'recently deleted list',
    );
    await tap(find.byKey(MenuKeys.restore(starters.id)));
    final restored = await waitFor(
      tester,
      () async => (await starters.reference.get(
        const GetOptions(source: Source.server),
      )).data()!,
      (d) => d['deletedAt'] == null,
      what: 'category restored',
    );
    expect(restored['name'], 'Starters');
    await waitFor(
      tester,
      rootData,
      (d) => (d['counts'] as Map)['categories'] == 2,
      what: 'counts after restore',
    );

    // 8. The rules refuse menu content created by the client (BR-011).
    await expectLater(
      db.collection('restaurants/$rid/items').add({
        'categoryId': mains.id,
        'name': 'Sneaky',
        'priceMinor': 1,
        'dietaryLabelId': 'vegetarian',
        'updatedAt': FieldValue.serverTimestamp(),
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
