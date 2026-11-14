// M04: item editor (FR-022 to FR-033, FR-029, AC-004, AC-006, AC-029).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/menu/presentation/item_editor.dart';
import 'package:owner_app/features/menu/presentation/menu_actions.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_menu.dart';
import 'helpers.dart';

Future<TestApp> openEditor(
  WidgetTester tester, {
  double width = 360,
  String currency = 'INR',
  String path = '/menu/item/new?category=c1',
  FakeMenuRepository? menu,
}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: FakeRestaurantRepository(
      restaurantData({'currency': currency}),
    ),
    menu: menu ?? sampleMenu(),
  );
  await app.go(Routes.menu);
  if (width < 600) {
    app.router.push(path);
    await tester.pumpAndSettle();
  }
  return app;
}

void main() {
  group('validation', () {
    testWidgets('name, price and dietary classification are required', (
      tester,
    ) async {
      final app = await openEditor(tester);
      expect(find.text('New item'), findsOneWidget);
      await app.tap(find.byKey(ItemEditorKeys.save));
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Enter a price.'), findsOneWidget);
      expect(find.text('Choose a dietary classification.'), findsOneWidget);
      expect(app.menu.createdItems, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('length limits come from FR-022', (tester) async {
      final app = await openEditor(tester);
      final name = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(ItemEditorKeys.name),
          matching: find.byType(TextField),
        ),
      );
      final description = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(ItemEditorKeys.description),
          matching: find.byType(TextField),
        ),
      );
      expect(name.maxLength, 80);
      expect(description.maxLength, 500);
      await app.dispose();
    });

    testWidgets('all four dietary classifications show icon and text '
        '(AC-006)', (tester) async {
      await openEditor(tester);
      for (final label in dietaryLabels) {
        expect(
          find.descendant(
            of: find.byKey(ItemEditorKeys.dietary(label.id)),
            matching: find.text(label.name),
          ),
          findsOneWidget,
        );
      }
      for (final tag in itemTags) {
        expect(find.byKey(ItemEditorKeys.tag(tag.id)), findsOneWidget);
      }
    });
  });

  group('create', () {
    for (final width in [360.0, 768.0, 1280.0]) {
      testWidgets('KWD 1.250 is stored as 1250 at $width px (AC-029)', (
        tester,
      ) async {
        final app = await openEditor(tester, width: width, currency: 'KWD');
        if (width >= 600) {
          await app.tap(find.byKey(MenuKeys.addItem));
        }
        expect(find.text('KWD prices have 3 decimal places.'), findsOneWidget);
        // A fourth decimal is refused as typed.
        await app.enter(ItemEditorKeys.price, '1.2505');
        expect(find.text('1.2505'), findsNothing);
        await app.enter(ItemEditorKeys.price, '1.25');
        await app.enter(ItemEditorKeys.name, '  Karak tea ');
        expect(find.text('1.250'), findsOneWidget, reason: 'padded on blur');
        await app.tap(find.byKey(ItemEditorKeys.dietary('vegetarian')));
        await app.tap(find.byKey(ItemEditorKeys.tag('new')));
        await app.tap(find.byKey(ItemEditorKeys.featured));
        await app.tap(find.byKey(ItemEditorKeys.save));

        final created = app.menu.createdItems.single;
        expect(created.name, 'Karak tea');
        expect(created.priceMinor, 1250);
        expect(created.categoryId, 'c1');
        expect(created.dietaryLabelId, 'vegetarian');
        expect(created.tagIds, ['new']);
        expect(created.featured, isTrue);
        expect(created.available, isTrue);
        // The editor switches to the new item so a photo can be added.
        expect(find.text('Edit item'), findsOneWidget);
        expect(
          find.text('Karak tea added. You can add a photo now.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('INR accepts 2 decimals and pads on blur', (tester) async {
      final app = await openEditor(tester);
      await app.enter(ItemEditorKeys.price, '129.5');
      await app.enter(ItemEditorKeys.name, 'Dosa');
      expect(find.text('129.50'), findsOneWidget);
      await app.tap(find.byKey(ItemEditorKeys.dietary('vegan')));
      await app.tap(find.byKey(ItemEditorKeys.save));
      expect(app.menu.createdItems.single.priceMinor, 12950);
    });

    testWidgets('the item limit shows the upgrade prompt', (tester) async {
      final menu = sampleMenu()
        ..nextError = callableError('limit-reached', {
          'limit': 'items',
          'max': 50,
        });
      final app = await openEditor(tester, menu: menu);
      await app.enter(ItemEditorKeys.name, 'One too many');
      await app.enter(ItemEditorKeys.price, '10');
      await app.tap(find.byKey(ItemEditorKeys.dietary('vegan')));
      await tester.tap(find.byKey(ItemEditorKeys.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Your plan allows 50 items.'), findsOneWidget);
    });
  });

  group('edit', () {
    testWidgets('writes only the changed fields; a new category moves the '
        'item (FR-097)', (tester) async {
      final app = await openEditor(tester, width: 1280);
      await app.tap(find.text('Paneer tikka'));
      expect(find.text('249.00'), findsOneWidget);
      FilledButton save() => tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(ItemEditorKeys.save),
          matching: find.byType(FilledButton),
        ),
      );
      expect(save().onPressed, isNull, reason: 'nothing changed yet');

      await app.enter(ItemEditorKeys.price, '259');
      await app.tap(find.byKey(ItemEditorKeys.tag('spicy')));
      await app.choose(ItemEditorKeys.category, 'Mains');
      expect(find.text('Unsaved changes'), findsOneWidget);
      await app.tap(find.byKey(ItemEditorKeys.save));

      expect(app.menu.updates['i1']!.single, {
        'priceMinor': 25900,
        'tagIds': <String>[],
      });
      expect(app.menu.calls.last, 'moveItems: i1->c2');
      expect(find.text('Changes saved to the draft.'), findsOneWidget);
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      final app = await openEditor(tester, path: Routes.menuItem('i1'));
      await app.enter(ItemEditorKeys.name, 'Paneer tikka (6 pcs)');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await app.tap(find.text('Cancel'));
      expect(find.text('Edit item'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await app.tap(find.widgetWithText(FilledButton, 'Discard'));
      expect(find.text('Edit item'), findsNothing);
      expect(app.menu.updates, isEmpty);
    });

    testWidgets('delete from the editor, with undo (FR-024, FR-098)', (
      tester,
    ) async {
      final app = await openEditor(tester, path: Routes.menuItem('i2'));
      await app.tap(find.byKey(ItemEditorKeys.delete));
      await app.tap(find.widgetWithText(FilledButton, 'Delete'));
      expect(app.menu.calls.last, 'deleteItems: i2');
      expect(find.text('Edit item'), findsNothing);
      await app.tap(find.text('Undo'));
      expect(app.menu.calls.last, 'restore: item i2');
    });
  });
}
