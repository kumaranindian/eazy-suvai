// M13: which App Check providers each build uses.
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

AppEnv env(AppEnvironment e, {bool emulators = false}) => AppEnv(
  environment: e,
  useEmulators: emulators,
  emulatorHost: 'localhost',
);

void main() {
  test('off on the emulators', () {
    final p = AppCheckPlan.of(
      env(AppEnvironment.dev, emulators: true),
      isWeb: false,
    );
    expect(p.enabled, isFalse);
  });

  test('debug providers on dev, real providers on prod', () {
    final dev = AppCheckPlan.of(env(AppEnvironment.dev), isWeb: false);
    expect((dev.enabled, dev.debug), (true, true));
    final prod = AppCheckPlan.of(env(AppEnvironment.prod), isWeb: false);
    expect((prod.enabled, prod.debug), (true, false));
  });

  test('web needs the reCAPTCHA Enterprise site key', () {
    expect(
      AppCheckPlan.of(env(AppEnvironment.prod), isWeb: true).enabled,
      isFalse,
    );
    final p = AppCheckPlan.of(
      env(AppEnvironment.prod),
      isWeb: true,
      webSiteKey: 'site-key',
    );
    expect((p.enabled, p.webSiteKey), (true, 'site-key'));
  });
}
