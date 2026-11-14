import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app.dart';

const widths = [360.0, 768.0, 1280.0];

void main() {
  group('menu models', () {
    test('MenuItem.fromMap reads every FR-022 field', () {
      final deleted = DateTime.utc(2026, 11, 1);
      final item = MenuItem.fromMap('i1', {
        'categoryId': 'c1',
        'name': 'Masala dosa',
        'description': 'Crisp',
        'image': null,
        'priceMinor': 12900,
        'dietaryLabelId': 'vegetarian',
        'tagIds': ['spicy', 3, 'new'],
        'available': false,
        'featured': true,
        'sequence': 2000,
        'deletedAt': Timestamp.fromDate(deleted),
        'deletedWith': 'c1',
      });
      expect(item.priceMinor, 12900);
      expect(item.tagIds, ['spicy', 'new']);
      expect(item.available, isFalse);
      expect(item.featured, isTrue);
      expect(item.isDeleted, isTrue);
      expect(
        item.restoreUntil!.isAtSameMomentAs(
          deleted.add(const Duration(days: 30)),
        ),
        isTrue,
      );
      expect(item.deletedWith, 'c1');
    });

    test('defaults: available, not featured, active category', () {
      final item = MenuItem.fromMap('i1', {'name': 'X'});
      expect(item.available, isTrue);
      expect(item.featured, isFalse);
      expect(item.isDeleted, isFalse);
      expect(MenuCategory.fromMap('c1', {'name': 'C'}).active, isTrue);
      expect(MenuCategory.fromMap('c1', {'active': false}).active, isFalse);
    });

    test('labels: colours, retired entries kept only for the current item', () {
      final veg = MenuLabel.fromMap(MenuLabelKind.dietary, 'vegetarian', {
        'name': 'Vegetarian',
        'icon': 'veg',
        'color': '#2E7D32',
        'sort': 10,
      });
      expect(veg.color, 0xFF2E7D32);
      expect(parseHexColor('red'), isNull);
      const old = MenuLabel(
        id: 'old',
        kind: MenuLabelKind.dietary,
        name: 'Old',
        sort: 5,
        retired: true,
      );
      expect(selectableLabels([veg, old]).map((l) => l.id), ['vegetarian']);
      expect(selectableLabels([veg, old], keep: ['old']).map((l) => l.id), [
        'old',
        'vegetarian',
      ]);
    });
  });

  group('sequencesAfterMove (FR-019, FR-028)', () {
    List<Sequenced> list(List<int> seqs) => [
      for (var i = 0; i < seqs.length; i++) (id: 'd$i', sequence: seqs[i]),
    ];

    test('moves one document between its new neighbours', () {
      final l = list([1000, 2000, 3000, 4000]);
      expect(sequencesAfterMove(l, 3, 1), {'d3': 1500});
      expect(sequencesAfterMove(l, 0, 3), {'d0': 5000});
      expect(sequencesAfterMove(l, 3, 0), {'d3': 500});
      expect(sequencesAfterMove(l, 1, 1), isEmpty);
    });

    test('renumbers with gaps of 1000 when there is no room', () {
      final l = list([1000, 1001, 1002]);
      expect(sequencesAfterMove(l, 2, 1), {'d2': 2000, 'd1': 3000});
      final ties = list([0, 0, 0]);
      expect(sequencesAfterMove(ties, 2, 0), {
        'd2': 1000,
        'd0': 2000,
        'd1': 3000,
      });
    });

    test('renumbered only returns changes', () {
      expect(renumbered(list([1000, 2500, 3000])), {'d1': 2000});
    });
  });

  group('price parsing (FR-029, BR-019)', () {
    test('KWD 1.250 is 1250 minor units (AC-029)', () {
      expect(parsePriceMinor('1.250', Currencies.kwd), 1250);
      expect(parsePriceMinor('1.25', Currencies.kwd), 1250);
      expect(parsePriceMinor('1', Currencies.kwd), 1000);
      expect(parsePriceMinor('1.2501', Currencies.kwd), isNull);
      expect(formatPriceInput(1250, Currencies.kwd), '1.250');
    });

    test('INR uses 2 decimals', () {
      expect(parsePriceMinor('129.50', Currencies.inr), 12950);
      expect(parsePriceMinor('129.505', Currencies.inr), isNull);
      expect(parsePriceMinor('', Currencies.inr), isNull);
      expect(parsePriceMinor('-5', Currencies.inr), isNull);
      expect(formatPriceInput(0, Currencies.inr), '0.00');
    });

    test('formatter allows only the currency decimals', () {
      TextEditingValue apply(Currency c, String old, String text) =>
          PriceInputFormatter(c).formatEditUpdate(
            TextEditingValue(text: old),
            TextEditingValue(text: text),
          );
      expect(apply(Currencies.kwd, '1.25', '1.250').text, '1.250');
      expect(apply(Currencies.kwd, '1.250', '1.2501').text, '1.250');
      expect(apply(Currencies.inr, '1.25', '1.255').text, '1.25');
      expect(apply(Currencies.inr, '1', '1,0').text, '1');
      expect(apply(Currencies.inr, '1', '-1').text, '1');
      expect(apply(Currencies.inr, '', '.5').text, '.5');
      // INR: 7 whole digits (999,999,999 paise).
      expect(apply(Currencies.inr, '1234567', '12345678').text, '1234567');
      const jpy = Currency(code: 'JPY', decimals: 0, defaultLocale: 'en');
      expect(apply(jpy, '12', '12.').text, '12');
    });
  });

  group('PriceField', () {
    Future<List<int?>> pump(
      WidgetTester tester,
      Currency currency, {
      int? initial,
    }) async {
      final values = <int?>[];
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Form(
              child: Column(
                children: [
                  PriceField(
                    key: const ValueKey('price'),
                    currency: currency,
                    label: 'Price',
                    initialMinor: initial,
                    onChanged: values.add,
                  ),
                  const TextField(key: ValueKey('other')),
                ],
              ),
            ),
          ),
        ),
      );
      return values;
    }

    for (final width in widths) {
      testWidgets('KWD: 1.25 becomes 1.250 and 1250 at $width px', (
        tester,
      ) async {
        await setSurfaceWidth(tester, width);
        final values = await pump(tester, Currencies.kwd);
        expect(find.text('KWD prices have 3 decimal places.'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('price')), '1.25');
        expect(values.last, 1250);
        await tester.tap(find.byKey(const ValueKey('other')));
        await tester.pump();
        expect(find.text('1.250'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('INR initial value, required and invalid messages', (
      tester,
    ) async {
      final values = await pump(tester, Currencies.inr, initial: 12900);
      expect(find.text('129.00'), findsOneWidget);
      expect(find.text('₹ '), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('price')), '');
      await tester.pump();
      expect(find.text('Enter a price.'), findsOneWidget);
      expect(values.last, isNull);
      await tester.enterText(find.byKey(const ValueKey('price')), '.');
      await tester.pump();
      expect(find.text('Enter a price like 12.50.'), findsOneWidget);
    });
  });

  group('MenuLabelBadge (FR-023, AC-006)', () {
    const labels = [
      MenuLabel(
        id: 'vegetarian',
        kind: MenuLabelKind.dietary,
        name: 'Vegetarian',
        icon: 'veg',
      ),
      MenuLabel(
        id: 'non-vegetarian',
        kind: MenuLabelKind.dietary,
        name: 'Non-vegetarian',
        icon: 'nonVeg',
      ),
      MenuLabel(
        id: 'vegan',
        kind: MenuLabelKind.dietary,
        name: 'Vegan',
        icon: 'vegan',
      ),
      MenuLabel(
        id: 'contains-egg',
        kind: MenuLabelKind.dietary,
        name: 'Contains egg',
        icon: 'egg',
      ),
    ];

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      testWidgets('shows icon and text for all four (${theme.brightness})', (
        tester,
      ) async {
        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: Column(
                children: [for (final l in labels) MenuLabelBadge(label: l)],
              ),
            ),
            theme: theme,
          ),
        );
        for (final l in labels) {
          expect(find.text(l.name), findsOneWidget);
        }
        expect(find.byType(MenuLabelIcon), findsNWidgets(4));
        expect(find.byIcon(Icons.eco), findsOneWidget);
        expect(find.byIcon(Icons.egg), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      });
    }
  });
}
