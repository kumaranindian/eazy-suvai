// PLACEHOLDER: replace by running, from apps/owner_app:
//   flutterfire configure --project=eazysuvai-prod //     --out=lib/firebase_options_prod.dart --platforms=web,android,ios
// Until then, run this app with --dart-define=USE_EMULATORS=true.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase project eazysuvai-prod is not configured yet. '
    'Run flutterfire configure (see the top of firebase_options_prod.dart) '
    'or use --dart-define=USE_EMULATORS=true.',
  );
}
