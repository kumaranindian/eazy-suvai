// M03: opening hours editor (FR-011: per weekday up to 3 slots, or closed).
import 'package:core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/restaurant/presentation/opening_hours_editor.dart';
import 'package:owner_app/features/restaurant/presentation/save_status.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

const _week = {
  'mon': '09:00-22:00',
  'tue': '09:00-22:00',
  'wed': '09:00-22:00',
  'thu': '09:00-22:00',
  'fri': '09:00-22:00',
  'sat': '09:00-22:00',
  'sun': '',
};

Future<TestApp> openHours(
  WidgetTester tester, {
  double width = 768,
  Map<String, String>? hours,
}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: FakeRestaurantRepository(
      restaurantData({'openingHours': ?hours}),
    ),
  );
  await app.go(Routes.hours);
  return app;
}

Future<void> autosave(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Map<String, Object?> lastHours(TestApp app) =>
    app.restaurant.updates.last['openingHours']! as Map<String, Object?>;

void main() {
  testWidgets('no hours yet: adding starts from every day 09:00–22:00', (
    tester,
  ) async {
    final app = await openHours(tester);
    expect(find.text('No opening hours yet'), findsOneWidget);
    await app.tap(find.text('Add opening hours'));
    await autosave(tester);
    expect(lastHours(app), {
      for (final d in Weekday.values) d.key: '09:00-22:00',
    });
    expect(find.byKey(HoursKeys.open(Weekday.mon)), findsOneWidget);
  });

  testWidgets('a day can be closed and opened again', (tester) async {
    final app = await openHours(tester, hours: _week);
    expect(
      tester.widget<Switch>(find.byKey(HoursKeys.open(Weekday.sun))).value,
      isFalse,
    );

    await app.tap(find.byKey(HoursKeys.open(Weekday.tue)));
    await autosave(tester);
    expect(lastHours(app)['tue'], '');

    await app.tap(find.byKey(HoursKeys.open(Weekday.sun)));
    await autosave(tester);
    expect(lastHours(app)['sun'], '09:00-22:00');
  });

  testWidgets('up to 3 slots a day; then "Add time slot" disappears', (
    tester,
  ) async {
    final app = await openHours(
      tester,
      hours: {..._week, 'mon': '07:00-10:00'},
    );
    await app.tap(find.byKey(HoursKeys.add(Weekday.mon)));
    await app.tap(find.byKey(HoursKeys.add(Weekday.mon)));
    expect(find.byKey(HoursKeys.add(Weekday.mon)), findsNothing);
    expect(find.byKey(HoursKeys.opens(Weekday.mon, 2)), findsOneWidget);
    await autosave(tester);
    expect(lastHours(app)['mon'], '07:00-10:00,11:00-13:00,14:00-16:00');

    await app.tap(find.byKey(HoursKeys.remove(Weekday.mon, 1)));
    await autosave(tester);
    expect(lastHours(app)['mon'], '07:00-10:00,14:00-16:00');
    expect(find.byKey(HoursKeys.add(Weekday.mon)), findsOneWidget);
  });

  testWidgets(
    'inline time fields: edits are saved; overlaps and bad times are refused',
    (tester) async {
      final app = await openHours(
        tester,
        hours: {..._week, 'mon': '09:00-12:00,13:00-17:00'},
      );

      await app.enter(HoursKeys.closes(Weekday.mon, 0), '14:00');
      expect(
        find.text('Time slots overlap. List them in order through the day.'),
        findsOneWidget,
      );
      await autosave(tester);
      expect(app.restaurant.updates, isEmpty);
      expect(find.text('Fix the highlighted fields to save'), findsOneWidget);

      await app.enter(HoursKeys.closes(Weekday.mon, 0), '9:6');
      expect(find.text('Use 24-hour time, like 09:30'), findsOneWidget);
      await autosave(tester);
      expect(app.restaurant.updates, isEmpty);

      await app.enter(HoursKeys.closes(Weekday.mon, 0), '12:30');
      await autosave(tester);
      expect(lastHours(app)['mon'], '09:00-12:30,13:00-17:00');
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets('a slot past midnight is allowed only as the last one', (
    tester,
  ) async {
    final app = await openHours(
      tester,
      hours: {..._week, 'fri': '18:00-02:00'},
    );
    await autosave(tester);
    await app.tap(find.byKey(HoursKeys.add(Weekday.fri)));
    expect(
      find.text('Only the last time slot of a day can run past midnight.'),
      findsOneWidget,
    );
    await autosave(tester);
    expect(app.restaurant.updates, isEmpty);
  });

  testWidgets("copy a day's hours to every day", (tester) async {
    final app = await openHours(
      tester,
      hours: {..._week, 'mon': '07:00-11:00,18:00-23:00'},
    );
    await app.tap(find.byKey(HoursKeys.copy(Weekday.mon)));
    await autosave(tester);
    expect(lastHours(app).values.toSet(), {'07:00-11:00,18:00-23:00'});
    expect(find.byKey(HoursKeys.opens(Weekday.sun, 1)), findsOneWidget);
  });

  testWidgets('removing all hours stores null', (tester) async {
    final app = await openHours(tester, hours: _week);
    await app.tap(find.text('Remove opening hours'));
    await tester.tap(find.widgetWithText(FilledButton, 'Remove opening hours'));
    await tester.pumpAndSettle();
    await autosave(tester);
    expect(app.restaurant.updates.last, {'openingHours': null});
    expect(find.text('No opening hours yet'), findsOneWidget);
  });

  testWidgets('360 px: slots open time pickers in a bottom sheet', (
    tester,
  ) async {
    final app = await openHours(
      tester,
      width: 360,
      hours: {..._week, 'mon': '09:00-22:00'},
    );
    expect(
      find.byKey(HoursKeys.opens(Weekday.mon, 0)),
      findsNothing,
      reason: 'no inline fields',
    );
    expect(find.byType(SaveBar), findsOneWidget);

    await app.tap(find.byKey(HoursKeys.slot(Weekday.mon, 0)));
    expect(find.text('Monday hours'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNWidgets(2));

    // Turn the "Closes" wheel: one hour earlier is 21:00.
    final hourWheel = find
        .descendant(
          of: find.byKey(HoursKeys.sheetCloses),
          matching: find.byType(CupertinoPicker),
        )
        .first;
    await tester.drag(hourWheel, const Offset(0, 32), warnIfMissed: false);
    await tester.pumpAndSettle();
    await app.tap(find.byKey(HoursKeys.sheetDone));
    expect(find.text('Monday hours'), findsNothing);
    await autosave(tester);
    expect(lastHours(app)['mon'], isNot('09:00-22:00'));
    expect((lastHours(app)['mon']! as String).startsWith('09:00-'), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [768.0, 1280.0]) {
    testWidgets('${width.toInt()} px renders inline fields without overflow', (
      tester,
    ) async {
      await openHours(tester, width: width, hours: _week);
      expect(find.byKey(HoursKeys.opens(Weekday.mon, 0)), findsOneWidget);
      expect(find.byType(SaveStatusIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
