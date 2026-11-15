import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'app_env.dart';

/// Which App Check providers a build uses (M13, architecture §6).
///
/// - Emulators: none (the emulators don't check tokens).
/// - Dev: the debug providers. Register each device's debug token in the
///   Firebase console (App Check → Apps → Manage debug tokens).
/// - Prod: Play Integrity (Android), App Attest with a DeviceCheck fallback
///   (iOS) and reCAPTCHA Enterprise (web, site key from
///   `--dart-define=RECAPTCHA_ENTERPRISE_KEY=...`).
///
/// On web without a site key App Check stays off and the build logs it;
/// production callables then refuse the calls, so a missing key is caught
/// on the first deploy check.
@immutable
class AppCheckPlan {
  const AppCheckPlan._({
    required this.enabled,
    this.debug = false,
    this.webSiteKey,
  });

  factory AppCheckPlan.of(
    AppEnv env, {
    required bool isWeb,
    String webSiteKey = const String.fromEnvironment(
      'RECAPTCHA_ENTERPRISE_KEY',
    ),
  }) {
    if (env.useEmulators) return const AppCheckPlan._(enabled: false);
    final debug = env.environment == AppEnvironment.dev;
    if (isWeb && webSiteKey.isEmpty) {
      return const AppCheckPlan._(enabled: false);
    }
    return AppCheckPlan._(
      enabled: true,
      debug: debug,
      webSiteKey: webSiteKey.isEmpty ? null : webSiteKey,
    );
  }

  final bool enabled;
  final bool debug;
  final String? webSiteKey;
}

/// Activates App Check for [env]. Call right after `Firebase.initializeApp`.
Future<void> activateAppCheck(AppEnv env) async {
  final plan = AppCheckPlan.of(env, isWeb: kIsWeb);
  if (!plan.enabled) {
    if (!env.useEmulators) {
      debugPrint('App Check is off: no RECAPTCHA_ENTERPRISE_KEY for web.');
    }
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerWeb: plan.webSiteKey == null
        ? null
        : ReCaptchaEnterpriseProvider(plan.webSiteKey!),
    providerAndroid: plan.debug
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: plan.debug
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
}
