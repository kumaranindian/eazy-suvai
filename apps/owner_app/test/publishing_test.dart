import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/menu/presentation/menu_page.dart';
import 'package:owner_app/features/publishing/domain/publish_models.dart';
import 'package:owner_app/features/publishing/presentation/preview_page.dart';
import 'package:owner_app/features/publishing/presentation/publish_problems.dart';

import 'fake_menu.dart';
import 'fake_publishing.dart';
import 'helpers.dart';

const widths = [360.0, 768.0, 1280.0];

/// A restaurant published as version [version], with the draft unchanged
/// ([changed] false) or edited since.
Map<String, dynamic> published({int version = 2, bool changed = false}) =>
    restaurantData({
      'publishedVersion': version,
      'publishedAt': DateTime.utc(2026, 11, 14, 10),
      'publishedDraftAt': DateTime.utc(2026, 11, 14, 10),
      'draftUpdatedAt': changed
          ? DateTime.utc(2026, 11, 14, 11)
          : DateTime.utc(2026, 11, 14, 9),
      'versionHistory': [
        for (var n = version; n >= 1; n--)
          {
            'n': n,
            'kind': n == 2 ? 'rollback' : 'publish',
            'rollbackOf': n == 2 ? 1 : null,
            'publishedAt': DateTime.utc(2026, 11, 13 + n, 10),
            'publishedBy': 'u1',
            'summary': {
              'added': n == 1 ? 5 : 0,
              'changed': n == 1 ? 0 : 2,
              'removed': 0,
              'profileChanged': false,
              'themeChanged': n == 2,
            },
          },
      ],
    });

PublishCheck checkWith({
  List<PublishProblem> problems = const [],
  ChangeSummary summary = const ChangeSummary(),
  int? current = 2,
  bool prices = false,
}) => PublishCheck(
  problems: problems,
  summary: summary,
  currentVersion: current,
  pricesNeedReview: prices,
);

Future<TestApp> pump(
  WidgetTester tester, {
  double width = 360,
  Map<String, dynamic>? data,
  FakePublishingRepository? publishing,
}) => pumpOwnerApp(
  tester,
  width: width,
  signedIn: verifiedOwner(),
  restaurant: FakeRestaurantRepository(data ?? restaurantData()),
  menu: sampleMenu(),
  publishing: publishing,
);

void main() {
  group('publish bar', () {
    for (final width in widths) {
      testWidgets('${width.toInt()} px: shown before the first publish', (
        tester,
      ) async {
        await pump(tester, width: width);
        final bar = find.byKey(PublishKeys.bar);
        expect(bar, findsOneWidget);
        expect(
          find.descendant(of: bar, matching: find.text('Not published yet')),
          findsOneWidget,
        );
        final barRect = tester.getRect(bar);
        if (width < 600) {
          // Above the bottom navigation.
          final nav = tester.getRect(
            find.byKey(ResponsiveScaffold.bottomBarKey),
          );
          expect(barRect.bottom, lessThanOrEqualTo(nav.top + 0.5));
        } else {
          // At the top of the content area, beside the navigation.
          expect(barRect.top, lessThan(200));
          expect(barRect.left, greaterThan(50));
        }
        expect(barRect.width, lessThanOrEqualTo(width));
        // Touch targets.
        expect(
          tester.getSize(find.byKey(PublishKeys.barPublish)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(PublishKeys.barPreview)).height,
          greaterThanOrEqualTo(48),
        );
      });
    }

    testWidgets('hidden while the live menu matches the draft', (tester) async {
      final app = await pump(tester, data: published());
      expect(find.byKey(PublishKeys.bar), findsNothing);

      // An edit after the publish (draftUpdatedAt moves on).
      app.restaurant.emit({'draftUpdatedAt': DateTime.utc(2026, 11, 14, 12)});
      await tester.pumpAndSettle();
      expect(find.text('Unpublished changes'), findsOneWidget);

      // A rollback that kept the draft.
      app.restaurant.emit({
        'draftUpdatedAt': DateTime.utc(2026, 11, 14, 9),
        'publishedDraftAt': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Unpublished changes'), findsOneWidget);
    });

    testWidgets('hidden for a suspended account', (tester) async {
      await pump(tester, data: restaurantData({'status': 'suspended'}));
      expect(find.byKey(PublishKeys.bar), findsNothing);
    });

    testWidgets('stays on detail pages inside the shell', (tester) async {
      final app = await pump(tester);
      await app.go('/settings/profile');
      expect(find.byKey(PublishKeys.bar), findsOneWidget);
    });
  });

  group('publish dialog', () {
    for (final width in widths) {
      testWidgets('${width.toInt()} px: summary, publish and confirmation', (
        tester,
      ) async {
        final publishing = FakePublishingRepository();
        final app = await pump(tester, width: width, publishing: publishing);
        publishing.onPublished = (v) => app.restaurant.emit({
          'publishedVersion': v,
          'publishedDraftAt': DateTime.utc(2026, 11, 14, 12),
          'draftUpdatedAt': DateTime.utc(2026, 11, 14, 11),
        });

        await app.tap(find.byKey(PublishKeys.barPublish));
        expect(find.byKey(PublishKeys.dialog), findsOneWidget);
        if (width < 600) {
          expect(find.byType(BottomSheet), findsOneWidget);
        } else {
          expect(find.byType(Dialog), findsOneWidget);
          expect(
            tester.getSize(find.byKey(PublishKeys.dialog)).width,
            lessThanOrEqualTo(560),
          );
        }
        expect(publishing.checks, ['rest_1']);
        expect(
          find.text(
            '1 category and 2 items go live at your menu link and QR code.',
          ),
          findsOneWidget,
        );
        expect(find.text('This becomes version 1.'), findsOneWidget);

        await app.tap(find.byKey(PublishKeys.confirm));
        expect(publishing.publishes, [false]);
        expect(find.byKey(PublishKeys.dialog), findsNothing);
        expect(find.text('Version 1 is live.'), findsOneWidget);
        // The draft now matches the live menu.
        expect(find.byKey(PublishKeys.bar), findsNothing);
      });

      testWidgets(
        '${width.toInt()} px: problems block publishing and link to fixes',
        (tester) async {
          final publishing = FakePublishingRepository(
            check: checkWith(
              current: null,
              summary: const ChangeSummary(firstPublish: true),
              problems: const [
                PublishProblem(PublishProblemCode.menuEmpty),
                PublishProblem(
                  PublishProblemCode.missingField,
                  target: ProblemTarget.item,
                  id: 'i1',
                  name: 'Idli',
                  field: 'priceMinor',
                ),
                PublishProblem(
                  PublishProblemCode.limitExceeded,
                  details: {'limit': 'items', 'max': 50, 'count': 51},
                ),
              ],
            ),
          );
          final app = await pump(tester, width: width, publishing: publishing);
          await app.tap(find.byKey(PublishKeys.barPublish));

          expect(find.text('Fix these before publishing'), findsOneWidget);
          expect(
            find.text(
              'Your menu is empty. Add at least one active category with an item in it.',
            ),
            findsOneWidget,
          );
          expect(find.text('Idli: enter a price.'), findsOneWidget);
          expect(
            find.text(
              'You have 51 items and your plan allows 50. Delete some or upgrade your plan.',
            ),
            findsOneWidget,
          );
          final confirm = tester.widget<AppPrimaryButton>(
            find.byKey(PublishKeys.confirm),
          );
          expect(confirm.onPressed, isNull);

          // "Fix" on the item opens its editor.
          await app.tap(find.byKey(PublishKeys.fix(1)));
          expect(find.byKey(PublishKeys.dialog), findsNothing);
          expect(find.byType(ItemEditorPage), findsOneWidget);
          expect(publishing.publishes, isEmpty);
        },
      );
    }

    testWidgets('"Fix" for profile and opening hours problems', (tester) async {
      final publishing = FakePublishingRepository(
        check: checkWith(
          problems: const [
            PublishProblem(
              PublishProblemCode.missingField,
              target: ProblemTarget.restaurant,
              field: 'name',
            ),
            PublishProblem(
              PublishProblemCode.invalidField,
              target: ProblemTarget.restaurant,
              field: 'openingHours.mon',
              details: {'issue': 'overlap'},
            ),
          ],
        ),
      );
      final app = await pump(tester, width: 1280, publishing: publishing);
      await app.tap(find.byKey(PublishKeys.barPublish));
      expect(find.text('Your restaurant needs a name.'), findsOneWidget);
      expect(
        find.text(
          'Check the opening hours for Monday: the times overlap or are out of order.',
        ),
        findsOneWidget,
      );
      await app.tap(find.byKey(PublishKeys.fix(1)));
      expect(app.location, '/settings/hours');
      await app.tap(find.byKey(PublishKeys.barPublish));
      await app.tap(find.byKey(PublishKeys.fix(0)));
      expect(app.location, '/settings/profile');
    });

    testWidgets('the change summary names what changed (FR-065)', (
      tester,
    ) async {
      final publishing = FakePublishingRepository(
        check: checkWith(
          summary: const ChangeSummary(
            themeChanged: true,
            items: ChangeLists(
              added: [ChangeRef('i9', 'Biryani')],
              changed: [ChangeRef('i1', 'Idli'), ChangeRef('i2', 'Vada')],
              removed: [ChangeRef('i3', 'Thali')],
            ),
            categories: ChangeLists(changed: [ChangeRef('c1', 'Tiffin')]),
          ),
        ),
      );
      final app = await pump(
        tester,
        data: published(changed: true),
        publishing: publishing,
      );
      await app.tap(find.byKey(PublishKeys.barPublish));
      expect(find.text('1 item added'), findsOneWidget);
      expect(find.text('Biryani'), findsOneWidget);
      expect(find.text('2 items changed'), findsOneWidget);
      expect(find.text('Idli, Vada'), findsOneWidget);
      expect(find.text('1 item removed'), findsOneWidget);
      expect(find.text('1 category changed'), findsOneWidget);
      expect(find.text('Theme changed'), findsOneWidget);
      expect(find.text('This becomes version 3.'), findsOneWidget);
    });

    testWidgets('no changes says so and still allows a publish', (
      tester,
    ) async {
      final app = await pump(
        tester,
        data: published(changed: true),
        publishing: FakePublishingRepository(check: checkWith()),
      );
      await app.tap(find.byKey(PublishKeys.barPublish));
      expect(
        find.text(
          'Nothing has changed since version 2. You can still publish it again.',
        ),
        findsOneWidget,
      );
      await app.tap(find.byKey(PublishKeys.confirm));
      expect(app.publishing.publishes, [false]);
    });

    testWidgets('a currency change needs the price checkbox (FR-103)', (
      tester,
    ) async {
      final publishing = FakePublishingRepository(
        check: checkWith(
          prices: true,
          problems: const [PublishProblem(PublishProblemCode.pricesNeedReview)],
        ),
      );
      final app = await pump(
        tester,
        data: published(changed: true),
        publishing: publishing,
      );
      await app.tap(find.byKey(PublishKeys.barPublish));
      expect(find.text('Fix these before publishing'), findsNothing);
      AppPrimaryButton confirm() =>
          tester.widget(find.byKey(PublishKeys.confirm));
      expect(confirm().onPressed, isNull);
      await app.tap(find.byKey(PublishKeys.pricesReviewed));
      expect(confirm().onPressed, isNotNull);
      await app.tap(find.byKey(PublishKeys.confirm));
      expect(publishing.publishes, [true]);
    });

    testWidgets('problems found at publish time replace the summary', (
      tester,
    ) async {
      final publishing = FakePublishingRepository()
        ..nextPublishError = callableError('publish-blocked', {
          'problems': [
            {'code': 'menu-empty'},
          ],
        });
      final app = await pump(tester, publishing: publishing);
      await app.tap(find.byKey(PublishKeys.barPublish));
      await app.tap(find.byKey(PublishKeys.confirm));
      expect(find.byKey(PublishKeys.dialog), findsOneWidget);
      expect(
        find.text(
          'Your menu is empty. Add at least one active category with an item in it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('unverified email is reported with a link', (tester) async {
      final publishing = FakePublishingRepository(
        check: checkWith(
          problems: const [PublishProblem(PublishProblemCode.emailNotVerified)],
        ),
      );
      final app = await pump(tester, publishing: publishing);
      await app.tap(find.byKey(PublishKeys.barPublish));
      expect(
        find.text('Verify your email address before publishing.'),
        findsOneWidget,
      );
    });
  });

  group('preview', () {
    testWidgets('360 px: full screen page with a Publish button', (
      tester,
    ) async {
      final app = await pump(tester);
      await app.tap(find.byKey(PublishKeys.barPreview));
      expect(find.byType(PreviewPage), findsOneWidget);
      expect(app.publishing.previews, 1);
      expect(find.byKey(const ValueKey('fake.html')), findsOneWidget);
      expect(
        find.text(
          'This is your draft. Customers see it only after you publish.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(PublishKeys.previewToggle), findsNothing);
      expect(find.byKey(PublishKeys.previewDesktop), findsNothing);
      // The page sits above the shell: no bottom navigation, no bar.
      expect(find.byKey(ResponsiveScaffold.bottomBarKey), findsNothing);
      await app.tap(find.byKey(PublishKeys.previewPublish));
      expect(find.byKey(PublishKeys.dialog), findsOneWidget);
    });

    testWidgets('768 px: one frame with a phone / desktop toggle', (
      tester,
    ) async {
      final app = await pump(tester, width: 768);
      await app.go('/preview');
      expect(find.byKey(PublishKeys.previewPhone), findsOneWidget);
      expect(find.byKey(PublishKeys.previewDesktop), findsNothing);
      await app.tap(find.text('Desktop'));
      expect(find.byKey(PublishKeys.previewDesktop), findsOneWidget);
      expect(find.byKey(PublishKeys.previewPhone), findsNothing);
    });

    testWidgets('1280 px: phone (390 px) beside desktop', (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await pump(tester, width: 1280);
      await app.go('/preview');
      expect(find.byKey(PublishKeys.previewPhone), findsOneWidget);
      expect(find.byKey(PublishKeys.previewDesktop), findsOneWidget);
      expect(find.byKey(PublishKeys.previewToggle), findsNothing);
      final phone = tester.getRect(find.byKey(PublishKeys.previewPhone));
      final desktop = tester.getRect(find.byKey(PublishKeys.previewDesktop));
      expect(phone.right, lessThanOrEqualTo(desktop.left));
      expect(
        find.bySemanticsLabel(RegExp('^Menu preview, Phone')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Menu preview, Desktop')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('blocking problems are announced', (tester) async {
      final app = await pump(
        tester,
        publishing: FakePublishingRepository(
          check: checkWith(
            problems: const [PublishProblem(PublishProblemCode.menuEmpty)],
          ),
        ),
      );
      await app.go('/preview');
      expect(
        find.textContaining('1 problem must be fixed before you can publish.'),
        findsOneWidget,
      );
    });
  });

  group('version history', () {
    for (final width in widths) {
      testWidgets('${width.toInt()} px: versions, live marker and restore', (
        tester,
      ) async {
        final publishing = FakePublishingRepository(check: checkWith());
        final app = await pump(
          tester,
          width: width,
          data: published(),
          publishing: publishing,
        );
        await app.go('/settings/versions');
        expect(find.text('Version history'), findsWidgets);
        expect(find.byKey(PublishKeys.version(2)), findsOneWidget);
        expect(find.byKey(PublishKeys.version(1)), findsOneWidget);
        expect(find.text('Live'), findsOneWidget);
        expect(find.textContaining('Restored from version 1'), findsOneWidget);
        expect(
          find.textContaining('5 added · 0 changed · 0 removed'),
          findsOneWidget,
        );
        expect(find.byKey(PublishKeys.restore(2)), findsNothing);
        // Nothing unpublished: no discard.
        expect(find.byKey(PublishKeys.discard), findsNothing);

        await app.tap(find.byKey(PublishKeys.restore(1)));
        expect(find.text('Restore version 1?'), findsOneWidget);
        await app.tap(find.byKey(PublishKeys.restoreReplace));
        await app.tap(find.byKey(PublishKeys.restoreConfirm));
        expect(publishing.rollbacks, [(1, false)]);
        expect(
          find.text('Version 1 is live again as version 3.'),
          findsOneWidget,
        );
      });
    }

    testWidgets('discarding unpublished changes asks first', (tester) async {
      final app = await pump(
        tester,
        data: published(changed: true),
        publishing: FakePublishingRepository(check: checkWith()),
      );
      await app.go('/settings/versions');
      await app.tap(find.byKey(PublishKeys.discard));
      expect(find.text('Discard unpublished changes?'), findsOneWidget);
      await app.tap(find.text('Discard changes').last);
      expect(app.publishing.discards, 1);
      expect(find.text('Your draft matches version 2 again.'), findsOneWidget);
    });

    testWidgets('empty before the first publish', (tester) async {
      final app = await pump(tester);
      await app.go('/settings/versions');
      expect(find.textContaining('Nothing is published yet.'), findsOneWidget);
    });

    testWidgets('Settings and the dashboard link to it', (tester) async {
      final app = await pump(tester, width: 1280, data: published());
      expect(find.text('Live · version 2'), findsOneWidget);
      await app.tap(find.byKey(const ValueKey('dashboard.versions')));
      expect(app.location, '/settings/versions');
      await app.go('/settings');
      expect(find.byKey(const ValueKey('settings.versions')), findsOneWidget);
    });

    testWidgets('the checklist step "Publish" opens the preview', (
      tester,
    ) async {
      final app = await pump(tester, width: 1280);
      await app.tap(find.byKey(const ValueKey('dashboard.step.publish')));
      expect(find.byType(PreviewPage), findsOneWidget);
    });
  });
}
