import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'app_env.dart';

/// Firebase options for the emulator demo project. No real project is needed.
FirebaseOptions demoFirebaseOptions() {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
  return FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:$platform:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: AppEnv.demoProjectId,
    storageBucket: '${AppEnv.demoProjectId}.appspot.com',
    iosBundleId: 'com.avail404.eazysuvai.ownerApp',
  );
}

/// Initializes Firebase for [env].
///
/// [optionsFor] returns the real options for dev or prod. These come from the
/// app's generated `firebase_options_<env>.dart` files.
Future<void> initFirebase(
  AppEnv env, {
  required FirebaseOptions Function(AppEnvironment env) optionsFor,
}) async {
  final options = env.useEmulators
      ? demoFirebaseOptions()
      : optionsFor(env.environment);
  await Firebase.initializeApp(options: options);
  if (!env.useEmulators) return;

  final host = env.emulatorHost;
  await FirebaseAuth.instance.useAuthEmulator(host, EmulatorPorts.auth);
  FirebaseFirestore.instance.useFirestoreEmulator(
    host,
    EmulatorPorts.firestore,
  );
  await FirebaseStorage.instance.useStorageEmulator(
    host,
    EmulatorPorts.storage,
  );
  FirebaseFunctions.instanceFor(
    region: AppEnv.region,
  ).useFunctionsEmulator(host, EmulatorPorts.functions);
}

/// Callable functions in the app's region. Use this, not
/// `FirebaseFunctions.instance`, which defaults to `us-central1`.
FirebaseFunctions get regionalFunctions =>
    FirebaseFunctions.instanceFor(region: AppEnv.region);
