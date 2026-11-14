import 'package:flutter/foundation.dart';

/// Build environment, chosen with `--dart-define=ENV=dev|prod`.
enum AppEnvironment { dev, prod }

/// Compile-time configuration.
///
/// ```
/// flutter run -d chrome --dart-define=ENV=dev --dart-define=USE_EMULATORS=true
/// ```
///
/// * `ENV`: `dev` (default) or `prod`. Picks the Firebase project
///   `eazy-suvai-dev` or `eazysuvai-prod`.
/// * `USE_EMULATORS`: `true` connects to the local Emulator Suite under the
///   demo project `demo-eazysuvai` and never touches a real project.
///   Ignored (forced off) when `ENV=prod`.
/// * `EMULATOR_HOST`: host of the emulators. Defaults to `localhost`, or
///   `10.0.2.2` on the Android emulator.
class AppEnv {
  const AppEnv({
    required this.environment,
    required this.useEmulators,
    required this.emulatorHost,
  });

  factory AppEnv.fromDefines() {
    const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
    const useEmulators = bool.fromEnvironment('USE_EMULATORS');
    const host = String.fromEnvironment('EMULATOR_HOST');
    return AppEnv.parse(
      envName: envName,
      useEmulators: useEmulators,
      emulatorHost: host.isEmpty ? null : host,
    );
  }

  /// Builds an [AppEnv] from raw values. Exposed for tests.
  factory AppEnv.parse({
    required String envName,
    bool useEmulators = false,
    String? emulatorHost,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final environment = switch (envName.toLowerCase()) {
      'dev' => AppEnvironment.dev,
      'prod' => AppEnvironment.prod,
      _ => throw ArgumentError.value(envName, 'ENV', 'Use dev or prod'),
    };
    final targetPlatform = platform ?? defaultTargetPlatform;
    final defaultHost = !isWeb && targetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return AppEnv(
      environment: environment,
      useEmulators: environment == AppEnvironment.dev && useEmulators,
      emulatorHost: emulatorHost ?? defaultHost,
    );
  }

  final AppEnvironment environment;
  final bool useEmulators;
  final String emulatorHost;

  bool get isProd => environment == AppEnvironment.prod;

  /// Firebase project id this build talks to.
  String get projectId => useEmulators
      ? demoProjectId
      : (isProd ? 'eazysuvai-prod' : 'eazy-suvai-dev');

  /// Base URL of the public menu (architecture §1; the final domain is an
  /// open decision). A restaurant's menu is `$menuBaseUrl/$slug`. Builds
  /// on the emulators use the dev site's address for display only.
  String get menuBaseUrl => isProd
      ? 'https://menu.eazysuvai.com'
      : 'https://eazy-suvai-dev-menu.web.app';

  /// Demo project used with the Emulator Suite. A `demo-` prefix makes the
  /// emulators refuse to reach any real Google service.
  static const demoProjectId = 'demo-eazysuvai';

  /// Region of Firestore, Storage and Functions (architecture §1).
  static const region = 'asia-south1';
}

/// Emulator ports, kept in sync with `firebase.json`.
abstract final class EmulatorPorts {
  static const auth = 9099;
  static const firestore = 8080;
  static const storage = 9199;
  static const functions = 5001;
}
