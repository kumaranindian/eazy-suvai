// End-to-end image flow on the Firebase Emulator Suite (M02, AC-005):
// a verified owner picks a logo → crop → upload to Storage → processImage
// (Functions emulator) → image object in Firestore → the rendition is shown
// through getDownloadURL. Also: a renamed PDF is refused, and another
// restaurant's image path is not writable.
//
// Run with: bash tool/integration.sh   (starts the emulators and Chrome)
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

const _host = 'localhost';
const _project = AppEnv.demoProjectId;

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 60),
  String what = 'condition',
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (done()) return;
  }
  throw TestFailure('Timed out waiting for $what');
}

/// Creates a verified owner with a restaurant and returns its id.
Future<String> createVerifiedOwner() async {
  final email = 'media${DateTime.now().millisecondsSinceEpoch}@example.com';
  await FirebaseAuth.instance.signOut();
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'Secret123!',
  );
  await regionalFunctions.httpsCallable('completeRegistration').call({
    'restaurantName': 'Media Test Kitchen',
    'ownerName': 'Priya Raman',
    'mobile': '9876543210',
    'country': 'IN',
    'businessType': 'restaurant',
    'city': 'Chennai',
  });
  await cred.user!.sendEmailVerification();
  final codes = await http.get(
    Uri.parse(
      'http://$_host:${EmulatorPorts.auth}/emulator/v1/projects/$_project/oobCodes',
    ),
  );
  final code = ((jsonDecode(codes.body) as Map)['oobCodes'] as List)
      .cast<Map<String, dynamic>>()
      .lastWhere((c) => c['email'] == email)['oobCode'];
  await http.post(
    Uri.parse(
      'http://$_host:${EmulatorPorts.auth}/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key',
    ),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'oobCode': code}),
  );
  await FirebaseAuth.instance.currentUser!.reload();
  final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
  expect(token.claims!['email_verified'], isTrue);
  return token.claims!['restaurantId'] as String;
}

Uint8List photo(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p.setRgb((p.x * 255) ~/ w, (p.y * 255) ~/ h, 120);
  }
  return img.encodePng(image);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TimeService.ensureInitialized();
    await initFirebase(
      AppEnv.parse(envName: 'dev', useEmulators: true),
      optionsFor: (_) => throw StateError('emulators only'),
    );
  });

  testWidgets('logo: pick → crop → upload → process → display (AC-005)', (
    tester,
  ) async {
    final rid = await createVerifiedOwner();
    final doc = FirebaseFirestore.instance.doc('restaurants/$rid');
    final picker = FakeImageFilePicker(
      PickedImageFile(bytes: photo(900, 700), name: 'logo.png'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageFilePickerProvider.overrideWithValue(picker)],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            CoreLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: CoreLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: StreamBuilder(
                stream: doc.snapshots(),
                builder: (context, snap) => ImagePickerField(
                  purpose: ImagePurpose.logo,
                  restaurantId: rid,
                  targetPath: 'restaurants/$rid',
                  label: 'Logo',
                  value: ImageObject.fromMap(snap.data?.data()?['logo']),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpUntil(
      tester,
      () => find.text('Add image').evaluate().isNotEmpty,
      what: 'field',
    );

    await tester.tap(find.text('Add image'));
    await pumpUntil(
      tester,
      () => find.byType(ImageCropDialog).evaluate().isNotEmpty,
      what: 'crop dialog',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Use image'));

    // processImage writes `ready`, then the 320 px rendition is displayed.
    await pumpUntil(tester, () {
      final images = tester.widgetList<RawImage>(
        find.descendant(
          of: find.byType(ResponsiveImage),
          matching: find.byType(RawImage),
        ),
      );
      return images.any((r) => r.image != null);
    }, what: 'rendition to display');

    final logo = ImageObject.fromMap((await doc.get()).get('logo'))!;
    expect(logo.status, ImageStatus.ready);
    expect(logo.contentType, 'image/jpeg');
    expect((logo.width, logo.height), (700, 700));
    expect(logo.path, startsWith('restaurants/$rid/images/'));
    expect(logo.renditions!.w320, endsWith('/w320.webp'));

    final storage = FirebaseStorage.instance;
    final original = await storage.ref(logo.path).getMetadata();
    expect(original.customMetadata?['processed'], 'true');
    for (final path in [
      logo.renditions!.w320,
      logo.renditions!.w640,
      logo.renditions!.w1280,
    ]) {
      expect((await storage.ref(path).getMetadata()).contentType, 'image/webp');
    }

    // A renamed PDF is refused on the device with a clear message.
    picker.next = PickedImageFile(
      bytes: Uint8List.fromList(utf8.encode('%PDF-1.7\n1 0 obj')),
      name: 'menu.jpg',
    );
    await tester.tap(find.text('Replace'));
    await pumpUntil(
      tester,
      () => find
          .textContaining("This file type isn't supported")
          .evaluate()
          .isNotEmpty,
      what: 'type error',
    );

    // The rules refuse uploads to another restaurant's path (AC-017).
    await expectLater(
      storage
          .ref(
            'restaurants/someone-else/images/abcdefghij0123456789/original.jpg',
          )
          .putData(
            photo(400, 400),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'purpose': 'logo',
                'targetPath': 'restaurants/someone-else',
                'field': 'logo',
              },
            ),
          ),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'unauthorized'),
      ),
    );
  });
}
