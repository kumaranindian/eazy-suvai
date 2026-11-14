// Firebase options for the dev project (eazy-suvai-dev).
//
// Web values come from the Firebase console (Project settings → Your apps).
// Firebase web config is not a secret; access is controlled by security rules
// and the API key's restrictions in Google Cloud.
//
// To add Android or iOS, run from apps/admin_app:
//   flutterfire configure --project=eazy-suvai-dev --out=lib/firebase_options_dev.dart --platforms=web
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Firebase project eazy-suvai-dev is configured for web only. '
      'Run flutterfire configure (see the top of firebase_options_dev.dart) '
      'or use --dart-define=USE_EMULATORS=true.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAAbOy0cZX9vgibQF9x4EFZ2kV4HYaK8nM',
    appId: '1:722009253659:web:9a82fe240b7743caf055be',
    messagingSenderId: '722009253659',
    projectId: 'eazy-suvai-dev',
    authDomain: 'eazy-suvai-dev.firebaseapp.com',
    storageBucket: 'eazy-suvai-dev.firebasestorage.app',
    measurementId: 'G-B1KX05FEWP',
  );
}
