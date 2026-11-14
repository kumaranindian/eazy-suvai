import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app.dart';

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('state views lay out at ${width.toInt()} px', (tester) async {
      await setSurfaceWidth(tester, width);
      var retried = false;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Column(
              children: [
                const Expanded(child: LoadingState(message: 'Wait')),
                const Expanded(
                  child: EmptyState(title: 'Nothing yet', message: 'Add one'),
                ),
                Expanded(child: ErrorState(onRetry: () => retried = true)),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirm dialog returns true only on confirm', (tester) async {
    bool? result;
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Scaffold(
            body: AppPrimaryButton(
              label: 'Delete',
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Delete item?',
                  message: 'This cannot be undone.',
                  destructive: true,
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('loading button ignores taps and has 48 px target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppPrimaryButton(label: 'Save', onPressed: () => taps++),
                AppPrimaryButton(
                  key: const Key('busy'),
                  label: 'Busy',
                  loading: true,
                  onPressed: () => taps++,
                ),
                AppIconButton(
                  icon: Icons.delete,
                  semanticLabel: 'Delete item',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.tap(find.byKey(const Key('busy')));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(FilledButton).first).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.byTooltip('Delete item'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('text field shows label and validates', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Form(
            key: key,
            child: AppTextField(
              label: 'Name',
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Name'), findsOneWidget);
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  test('error codes round-trip and unknown falls back', () {
    for (final c in AppErrorCode.values) {
      expect(AppErrorCode.fromWire(c.wire), c);
    }
    expect(AppErrorCode.fromWire('nope'), AppErrorCode.unknown);
    expect(AppErrorCode.fromWire(null), AppErrorCode.unknown);
  });

  test('AppEnv parsing', () {
    final dev = AppEnv.parse(envName: 'dev', useEmulators: true, isWeb: true);
    expect(dev.projectId, 'demo-eazysuvai');
    expect(dev.emulatorHost, 'localhost');

    final android = AppEnv.parse(
      envName: 'dev',
      useEmulators: true,
      isWeb: false,
      platform: TargetPlatform.android,
    );
    expect(android.emulatorHost, '10.0.2.2');

    final prod = AppEnv.parse(envName: 'prod', useEmulators: true);
    expect(prod.useEmulators, isFalse, reason: 'prod never uses emulators');
    expect(prod.projectId, 'eazysuvai-prod');
    expect(AppEnv.parse(envName: 'dev').projectId, 'eazysuvai-dev');
    expect(() => AppEnv.parse(envName: 'staging'), throwsArgumentError);
  });
}
