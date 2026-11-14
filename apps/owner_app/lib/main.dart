import 'package:core/core.dart';
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
  await initFirebase(
    AppEnv.fromDefines(),
    optionsFor: (env) => switch (env) {
      AppEnvironment.dev => dev.DefaultFirebaseOptions.currentPlatform,
      AppEnvironment.prod => prod.DefaultFirebaseOptions.currentPlatform,
    },
  );
  runApp(const ProviderScope(child: OwnerApp()));
}
