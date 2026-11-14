// M04: menu manager (FR-015 to FR-028, FR-095, FR-097, FR-098, FRD §5.4,
// AC-003, AC-004, AC-006, AC-027).
import 'dart:async';

import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/menu/presentation/category_dialogs.dart';
import 'package:owner_app/features/menu/presentation/item_editor.dart';
import 'package:owner_app/features/menu/presentation/menu_actions.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_menu.dart';
import 'helpers.dart';

Future<TestApp> openMenu(
  WidgetTester tester, {
  double width = 1280,
  FakeMenuRepository? menu,
}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    menu: menu ?? sampleMenu(),
  );
  await app.go(Routes.menu);
  return app;
}

void main() {
  group('layout at three widths', () {
    testWidgets('360 px: categories only; a category opens its items page', (
      tester,
    ) async {
      final app = await openMenu(tester, width: 360);
      expect(find.byKey(MenuKeys.categoryPane), findsOneWidget);
      expect(find.byKey(MenuKeys.itemPane), findsNothing);
      expect(find.text('2 items'), findsOneWidget);

      await app.tap(find.byKey(MenuKeys.category('c1')));
      // push keeps the shell's location; the page is what changes.
      expect(find.byKey(MenuKeys.itemPane), findsOneWidget);
      expect(find.byKey(MenuKeys.categoryPane), findsNothing);
      expect(find.text('Paneer tikka'), findsOneWidget);
      expect(find.text('₹249.00'), findsOneWidget);
      // Dietary label shows icon and text (FR-023, AC-006).
      expect(find.text('Vegetarian'), findsWidgets);
      expect(find.text('Sold out'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Opening an item shows the full-screen editor above the nav bar.
      await app.tap(find.text('Paneer tikka'));
      expect(find.text('Edit item'), findsOneWidget);
      expect(find.byKey(ItemEditorKeys.save), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768 px: categories and items side by side; editor dialog', (
      tester,
    ) async {
      final app = await openMenu(tester, width: 768);
      expect(find.byKey(MenuKeys.categoryPane), findsOneWidget);
      expect(find.byKey(MenuKeys.itemPane), findsOneWidget);
      expect(find.byKey(MenuKeys.editorPane), findsNothing);
      expect(find.text('Paneer tikka'), findsOneWidget);

      await app.tap(find.text('Paneer tikka'));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Edit item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280 px: three panes; the editor opens on the right', (
      tester,
    ) async {
      final app = await openMenu(tester);
      expect(find.byKey(MenuKeys.categoryPane), findsOneWidget);
      expect(find.byKey(MenuKeys.itemPane), findsOneWidget);
      expect(find.byKey(MenuKeys.editorPane), findsOneWidget);
      expect(find.text('No item selected'), findsOneWidget);

      await app.tap(find.text('Paneer tikka'));
      expect(app.location, Routes.menu);
      expect(
        find.descendant(
          of: find.byKey(MenuKeys.editorPane),
          matching: find.byKey(ItemEditorKeys.name),
        ),
        findsOneWidget,
      );
      await app.tap(find.byKey(MenuKeys.category('c2')));
      expect(find.text('Veg biryani'), findsOneWidget);
      expect(find.text('Paneer tikka'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('availability (FR-025, FR-095, FRD §5.4)', () {
    testWidgets('the switch changes at once and writes the item', (
      tester,
    ) async {
      final menu = sampleMenu()..availabilityGate = Completer();
      final app = await openMenu(tester, menu: menu);
      Switch sw() =>
          tester.widget<Switch>(find.byKey(MenuKeys.itemAvailable('i1')));
      expect(sw().value, isTrue);
      await tester.tap(find.byKey(MenuKeys.itemAvailable('i1')));
      await tester.pump();
      expect(sw().value, isFalse, reason: 'optimistic');
      expect(menu.calls.last, 'setAvailability: i1=false');
      menu.availabilityGate!.complete();
      await tester.pumpAndSettle();
      expect(sw().value, isFalse);
      expect(menu.items.firstWhere((i) => i.id == 'i1').available, isFalse);
      await app.dispose();
    });

    testWidgets('a failed write rolls back and says why', (tester) async {
      final menu = sampleMenu()
        ..availabilityGate = Completer()
        ..nextError = callableError('permission-denied');
      final app = await openMenu(tester, menu: menu);
      await tester.tap(find.byKey(MenuKeys.itemAvailable('i1')));
      await tester.pump();
      expect(
        tester.widget<Switch>(find.byKey(MenuKeys.itemAvailable('i1'))).value,
        isFalse,
      );
      menu.availabilityGate!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(find.byKey(MenuKeys.itemAvailable('i1'))).value,
        isTrue,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      await app.dispose();
    });

    testWidgets('"Sold out" filter shows only unavailable items', (
      tester,
    ) async {
      final app = await openMenu(tester, width: 360);
      await app.tap(find.byKey(MenuKeys.allItems));
      expect(find.text('Veg biryani'), findsOneWidget);
      expect(find.text('Sold out (1)'), findsOneWidget);
      await app.tap(find.byKey(MenuKeys.filterSoldOut));
      expect(find.text('Chicken 65'), findsOneWidget);
      expect(find.text('Paneer tikka'), findsNothing);
      expect(find.text('Veg biryani'), findsNothing);
    });

    testWidgets('search and the featured filter', (tester) async {
      final app = await openMenu(tester);
      await app.tap(find.byKey(MenuKeys.allItems));
      await tester.enterText(find.byKey(MenuKeys.search), 'tikka');
      await tester.pumpAndSettle();
      expect(find.text('Paneer tikka'), findsOneWidget);
      expect(find.text('Chicken 65'), findsNothing);
      await tester.enterText(find.byKey(MenuKeys.search), '');
      await app.tap(find.byKey(MenuKeys.filterFeatured));
      expect(find.text('Veg biryani'), findsOneWidget);
      expect(find.text('Paneer tikka'), findsNothing);
    });
  });

  group('bulk actions on wide screens (FR-097)', () {
    testWidgets('bulk sold out and bulk move', (tester) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, menu: menu);
      expect(find.byKey(MenuKeys.bulkBar), findsNothing);
      await app.tap(find.byKey(MenuKeys.itemSelect('i1')));
      expect(find.byKey(MenuKeys.bulkBar), findsOneWidget);
      await app.tap(find.byKey(MenuKeys.bulkSelectAll));
      expect(find.text('2 selected'), findsOneWidget);

      await app.tap(find.byKey(MenuKeys.bulkSoldOut));
      expect(menu.calls.last, 'setAvailability: i1,i2=false');

      await app.tap(find.byKey(MenuKeys.bulkMove));
      await app.tap(find.byKey(const ValueKey('pickCategory.c2')));
      expect(menu.calls.last, 'moveItems: i1,i2->c2');
      expect(find.byKey(MenuKeys.bulkBar), findsNothing);
      expect(find.text('2 items moved to Mains.'), findsOneWidget);
    });

    testWidgets('no bulk selection on phones', (tester) async {
      final app = await openMenu(tester, width: 360);
      await app.tap(find.byKey(MenuKeys.category('c1')));
      expect(find.byKey(MenuKeys.itemSelect('i1')), findsNothing);
    });
  });

  group('reorder (FR-019, FR-028)', () {
    testWidgets('"Move down" is the keyboard alternative to dragging', (
      tester,
    ) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, menu: menu);
      await app.tap(find.byKey(MenuKeys.itemMenu('i1')));
      await app.tap(find.text('Move down'));
      expect(menu.reorders.last, {'i1': 3000});

      await app.tap(find.byKey(MenuKeys.categoryMenu('c2')));
      await app.tap(find.text('Move up'));
      expect(menu.reorders.last, {'c2': 500});
      // Mains now comes first.
      final starters = tester.getTopLeft(find.byKey(MenuKeys.category('c1')));
      final mains = tester.getTopLeft(find.byKey(MenuKeys.category('c2')));
      expect(mains.dy, lessThan(starters.dy));
    });

    testWidgets('dragging the handle reorders categories', (tester) async {
      final menu = sampleMenu();
      await openMenu(tester, menu: menu);
      final handle = find.descendant(
        of: find.byKey(MenuKeys.category('c1')),
        matching: find.byIcon(Icons.drag_indicator),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kPressTimeout);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(menu.reorders.single, {'c1': 3000});
    });
  });

  group('categories (FR-015 to FR-018, AC-003, AC-027)', () {
    testWidgets('add a category, and toggle it inactive', (tester) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, menu: menu);
      await app.tap(find.byKey(MenuKeys.addCategory));
      await app.tap(find.byKey(CategoryDialogKeys.save));
      expect(find.text('Enter a name.'), findsOneWidget);
      await app.enter(CategoryDialogKeys.name, 'Desserts');
      await app.tap(find.byKey(CategoryDialogKeys.save));
      expect(menu.calls, contains('createCategory: Desserts'));
      expect(find.text('Desserts'), findsWidgets);

      await app.tap(find.byKey(MenuKeys.categoryActive('c1')));
      expect(menu.updates['c1']!.last, {'active': false});
      expect(find.text('2 items · Hidden'), findsOneWidget);
    });

    testWidgets('deleting a category with items: move them', (tester) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, menu: menu);
      await app.tap(find.byKey(MenuKeys.categoryMenu('c1')));
      await app.tap(find.text('Delete'));
      expect(find.text('Delete Starters?'), findsOneWidget);
      expect(
        find.text('This category has 2 items. What should happen to them?'),
        findsOneWidget,
      );
      await app.tap(find.byKey(CategoryDialogKeys.confirm));
      expect(menu.calls.last, 'deleteCategory: c1 move c2');
      expect(find.text('Starters'), findsNothing);
    });

    testWidgets('deleting a category with items: delete all needs the name '
        'typed (AC-027)', (tester) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, width: 360, menu: menu);
      await app.tap(find.byKey(MenuKeys.categoryMenu('c1')));
      await app.tap(find.text('Delete'));
      expect(find.byType(BottomSheet), findsOneWidget);
      await app.tap(find.byKey(CategoryDialogKeys.modeDeleteAll));
      FilledButton confirm() =>
          tester.widget<FilledButton>(find.byKey(CategoryDialogKeys.confirm));
      expect(find.text('Delete category and 2 items'), findsOneWidget);
      expect(confirm().onPressed, isNull);
      await app.enter(CategoryDialogKeys.confirmName, 'Start');
      expect(confirm().onPressed, isNull);
      await app.enter(CategoryDialogKeys.confirmName, 'starters ');
      expect(confirm().onPressed, isNotNull);
      await app.tap(find.byKey(CategoryDialogKeys.confirm));
      expect(menu.calls.last, 'deleteCategory: c1 deleteAll starters ');
      expect(find.text('Starters moved to Recently deleted.'), findsOneWidget);
    });

    testWidgets('an empty category needs a single confirmation', (
      tester,
    ) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, menu: menu);
      await app.tap(find.byKey(MenuKeys.addCategory));
      await app.enter(CategoryDialogKeys.name, 'Empty');
      await app.tap(find.byKey(CategoryDialogKeys.save));
      await app.tap(find.byKey(MenuKeys.categoryMenu('c100')));
      await app.tap(find.text('Delete'));
      expect(find.text('Delete Empty?'), findsOneWidget);
      await app.tap(find.widgetWithText(FilledButton, 'Delete'));
      expect(menu.calls.last, 'deleteCategory: c100 deleteAll ');
    });
  });

  group('plan limits (BR-011)', () {
    testWidgets('limit-reached shows the upgrade prompt', (tester) async {
      final menu = sampleMenu()
        ..nextError = callableError('limit-reached', {
          'limit': 'categories',
          'max': 10,
        });
      final app = await openMenu(tester, menu: menu);
      await app.tap(find.byKey(MenuKeys.addCategory));
      await app.enter(CategoryDialogKeys.name, 'Eleventh');
      // The Save spinner keeps animating under the prompt: pump, not settle.
      await tester.tap(find.byKey(CategoryDialogKeys.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Plan limit reached'), findsOneWidget);
      expect(
        find.textContaining('Your plan allows 10 categories.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(MenuKeys.upgrade));
      await tester.pumpAndSettle();
      expect(app.location, Routes.plan);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Plans'), findsWidgets);
    });
  });

  group('Recently deleted (FR-098, AC-028)', () {
    testWidgets('restores a deleted item, and asks for a category when its '
        'own is deleted', (tester) async {
      final menu = sampleMenu();
      final app = await openMenu(tester, menu: menu);
      await app.tap(find.byKey(MenuKeys.category('c2')));
      await app.tap(find.byKey(MenuKeys.itemMenu('i3')));
      await app.tap(find.text('Delete'));
      await app.tap(find.widgetWithText(FilledButton, 'Delete'));
      expect(menu.calls.last, 'deleteItems: i3');

      // Delete Mains too (now empty), so i3's category is gone.
      await app.tap(find.byKey(MenuKeys.categoryMenu('c2')));
      await app.tap(find.text('Delete'));
      await app.tap(find.widgetWithText(FilledButton, 'Delete'));

      await app.tap(find.byKey(MenuKeys.recentlyDeleted));
      expect(app.location, Routes.menuDeleted);
      expect(find.text('Veg biryani'), findsOneWidget);
      expect(find.text('Mains (deleted) · 30 days left'), findsOneWidget);
      await app.tap(find.byKey(MenuKeys.restore('i3')));
      expect(find.text('Restore Veg biryani into'), findsOneWidget);
      await app.tap(find.byKey(const ValueKey('pickCategory.c1')));
      expect(menu.calls.last, 'restore: item i3->c1');
      expect(find.text('Veg biryani restored to your draft.'), findsOneWidget);

      await app.tap(find.byKey(MenuKeys.restore('c2')));
      expect(menu.calls.last, 'restore: category c2');
      expect(find.text('Nothing deleted'), findsOneWidget);
    });
  });
}
