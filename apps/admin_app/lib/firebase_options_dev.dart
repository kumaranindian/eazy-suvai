// PLACEHOLDER: replace by running, from apps/admin_app:
//   flutterfire configure --project=eazysuvai-dev //     --out=lib/firebase_options_dev.dart --platforms=web
// Until then, run this app with --dart-define=USE_EMULATORS=true.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase project eazysuvai-dev is not configured yet. '
    'Run flutterfire configure (see the top of firebase_options_dev.dart) '
    'or use --dart-define=USE_EMULATORS=true.',
  );
}
