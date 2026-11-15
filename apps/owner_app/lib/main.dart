import 'package:core/core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

/// Run against the emulators:
/// `flutter run -d chrome --dart-define=ENV=dev --dart-define=USE_EMULATORS=true`
Future<void> main() async {
  // Path URLs (/menu, not /#/menu) so deep links and Hosting rewrites work.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  TimeService.ensureInitialized();
  final env = AppEnv.fromDefines();
  await initFirebase(
    env,
    optionsFor: (env) => switch (env) {
      AppEnvironment.dev => dev.DefaultFirebaseOptions.currentPlatform,
      AppEnvironment.prod => prod.DefaultFirebaseOptions.currentPlatform,
    },
  );
  await _initCrashlytics(env);
  runApp(const ProviderScope(child: OwnerApp()));
}

/// Crash reports from Android and iOS (M13). Crashlytics has no web SDK; on
/// the emulators nothing is collected.
Future<void> _initCrashlytics(AppEnv env) async {
  if (kIsWeb || env.useEmulators) return;
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
